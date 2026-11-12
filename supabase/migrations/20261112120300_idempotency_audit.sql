-- Server-side idempotency and audit helpers.
-- These functions are callable only by the service role through Edge Functions.

create or replace function public.begin_operation(
  p_operation_id uuid,
  p_operation text,
  p_entity_type text,
  p_entity_id uuid,
  p_payload_hash text,
  p_actor_type text default 'admin'
)
returns public.operation_registry
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_row public.operation_registry;
begin
  if p_operation_id is null then
    raise exception using errcode = '22023', message = 'operation_id wajib diisi';
  end if;

  if p_actor_type not in ('admin', 'system') then
    raise exception using errcode = '22023', message = 'actor_type tidak valid';
  end if;

  if p_operation is null
    or char_length(btrim(p_operation)) not between 1 and 100 then
    raise exception using errcode = '22023', message = 'operation tidak valid';
  end if;

  if p_entity_type is null
    or char_length(btrim(p_entity_type)) not between 1 and 100 then
    raise exception using errcode = '22023', message = 'entity_type tidak valid';
  end if;

  if p_payload_hash is null or p_payload_hash !~ '^[0-9a-f]{64}$' then
    raise exception using errcode = '22023', message = 'payload_hash tidak valid';
  end if;

  insert into public.operation_registry (
    operation_id,
    actor_type,
    operation,
    entity_type,
    entity_id,
    payload_hash
  ) values (
    p_operation_id,
    p_actor_type,
    btrim(p_operation),
    btrim(p_entity_type),
    p_entity_id,
    p_payload_hash
  )
  on conflict (operation_id) do nothing
  returning * into v_row;

  if not found then
    select *
    into v_row
    from public.operation_registry
    where operation_id = p_operation_id
    for update;

    if not found then
      raise exception using errcode = 'P0002', message = 'operation_not_found';
    end if;

    if v_row.payload_hash <> p_payload_hash then
      raise exception using
        errcode = 'P0001',
        message = 'operation_payload_mismatch';
    end if;

    if v_row.actor_type <> p_actor_type
      or v_row.operation <> btrim(p_operation)
      or v_row.entity_type <> btrim(p_entity_type)
      or v_row.entity_id is distinct from p_entity_id then
      raise exception using
        errcode = 'P0001',
        message = 'operation_metadata_mismatch';
    end if;
  end if;

  return v_row;
end;
$function$;

create or replace function public.complete_operation(
  p_operation_id uuid,
  p_response jsonb,
  p_status text default 'succeeded',
  p_error_code text default null
)
returns public.operation_registry
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_row public.operation_registry;
begin
  if p_operation_id is null then
    raise exception using errcode = '22023', message = 'operation_id wajib diisi';
  end if;

  if p_status not in ('succeeded', 'failed') then
    raise exception using errcode = '22023', message = 'status tidak valid';
  end if;

  if p_status = 'succeeded' and p_response is null then
    raise exception using
      errcode = '22023',
      message = 'response wajib diisi untuk status succeeded';
  end if;

  if p_error_code is not null and char_length(p_error_code) > 100 then
    raise exception using errcode = '22023', message = 'error_code terlalu panjang';
  end if;

  update public.operation_registry
  set
    status = p_status,
    response = p_response,
    error_code = p_error_code,
    completed_at = pg_catalog.now(),
    updated_at = pg_catalog.now()
  where operation_id = p_operation_id
    and status = 'processing'
  returning * into v_row;

  if not found then
    select *
    into v_row
    from public.operation_registry
    where operation_id = p_operation_id
    for update;

    if not found then
      raise exception using errcode = 'P0002', message = 'operation_not_found';
    end if;

    -- Repeating the same completion is safe; changing a final result is not.
    if v_row.status = p_status then
      return v_row;
    end if;

    raise exception using
      errcode = 'P0001',
      message = 'operation_already_completed';
  end if;

  return v_row;
end;
$function$;

create or replace function public.fail_operation(
  p_operation_id uuid,
  p_error_code text
)
returns public.operation_registry
language sql
security definer
set search_path = ''
as $function$
  select public.complete_operation(
    p_operation_id,
    null::jsonb,
    'failed',
    p_error_code
  );
$function$;

create or replace function public.append_audit_log(
  p_actor_type text,
  p_action text,
  p_entity_type text,
  p_entity_id uuid default null,
  p_operation_id uuid default null,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_id uuid;
begin
  if p_actor_type not in ('admin', 'system') then
    raise exception using errcode = '22023', message = 'actor_type tidak valid';
  end if;

  if p_action is null
    or char_length(btrim(p_action)) not between 1 and 100 then
    raise exception using errcode = '22023', message = 'action tidak valid';
  end if;

  if p_entity_type is null
    or char_length(btrim(p_entity_type)) not between 1 and 100 then
    raise exception using errcode = '22023', message = 'entity_type tidak valid';
  end if;

  if p_metadata is null
    or jsonb_typeof(p_metadata) <> 'object'
    or pg_column_size(p_metadata) > 8192 then
    raise exception using errcode = '22023', message = 'metadata tidak valid';
  end if;

  insert into public.audit_logs (
    actor_type,
    action,
    entity_type,
    entity_id,
    operation_id,
    metadata
  ) values (
    p_actor_type,
    btrim(p_action),
    btrim(p_entity_type),
    p_entity_id,
    p_operation_id,
    p_metadata
  )
  returning id into v_id;

  return v_id;
end;
$function$;

revoke all on function public.begin_operation(uuid, text, text, uuid, text, text)
  from public;
revoke all on function public.begin_operation(uuid, text, text, uuid, text, text)
  from anon;
revoke all on function public.begin_operation(uuid, text, text, uuid, text, text)
  from authenticated;
grant execute on function public.begin_operation(uuid, text, text, uuid, text, text)
  to service_role;

revoke all on function public.complete_operation(uuid, jsonb, text, text)
  from public;
revoke all on function public.complete_operation(uuid, jsonb, text, text)
  from anon;
revoke all on function public.complete_operation(uuid, jsonb, text, text)
  from authenticated;
grant execute on function public.complete_operation(uuid, jsonb, text, text)
  to service_role;

revoke all on function public.fail_operation(uuid, text) from public;
revoke all on function public.fail_operation(uuid, text) from anon;
revoke all on function public.fail_operation(uuid, text) from authenticated;
grant execute on function public.fail_operation(uuid, text) to service_role;

revoke all on function public.append_audit_log(text, text, text, uuid, uuid, jsonb)
  from public;
revoke all on function public.append_audit_log(text, text, text, uuid, uuid, jsonb)
  from anon;
revoke all on function public.append_audit_log(text, text, text, uuid, uuid, jsonb)
  from authenticated;
grant execute on function public.append_audit_log(text, text, text, uuid, uuid, jsonb)
  to service_role;
