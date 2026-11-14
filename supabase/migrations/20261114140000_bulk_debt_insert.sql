-- Atomic bulk debt creation for the offline outbox.
--
-- One operation ID covers the whole batch. Idempotency, all debt inserts, and
-- the audit entry happen in one PostgreSQL transaction: either every debt is
-- created or none is.

create or replace function public.admin_bulk_create_debts(
  p_operation_id uuid,
  p_entity_id uuid,
  p_payload jsonb,
  p_payload_hash text,
  p_session_id uuid,
  p_device_id text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_operation public.operation_registry;
  v_response jsonb;
  v_results jsonb;
  v_count integer;
begin
  if p_operation_id is null or p_entity_id is null then
    raise exception using errcode = '22023', message = 'ID batch tidak valid';
  end if;

  if p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    raise exception using errcode = '22023', message = 'payload tidak valid';
  end if;

  if coalesce(p_payload->>'id', '') <> p_entity_id::text then
    raise exception using errcode = '22023', message = 'entity_id tidak konsisten';
  end if;

  if jsonb_typeof(p_payload->'debts') <> 'array' then
    raise exception using errcode = '22023', message = 'daftar hutang tidak valid';
  end if;

  v_count := jsonb_array_length(p_payload->'debts');
  if v_count < 1 or v_count > 50 then
    raise exception using
      errcode = '22023',
      message = 'Jumlah hutang dalam batch harus 1-50';
  end if;

  if p_session_id is null then
    raise exception using errcode = '22023', message = 'session_id tidak valid';
  end if;

  if p_device_id is null
    or char_length(btrim(p_device_id)) not between 1 and 200 then
    raise exception using errcode = '22023', message = 'device_id tidak valid';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(p_payload->'debts') as elem(value)
    where nullif(btrim(value->>'id'), '') is null
  ) then
    raise exception using errcode = '22023', message = 'ID hutang tidak valid';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(p_payload->'debts') as elem(value)
    group by value->>'id'
    having count(*) > 1
  ) then
    raise exception using errcode = 'P0001', message = 'ID hutang duplikat';
  end if;

  v_operation := public.begin_operation(
    p_operation_id,
    'create',
    'debt_batch',
    p_entity_id,
    p_payload_hash
  );

  if v_operation.status = 'succeeded' then
    return coalesce(
      v_operation.response,
      jsonb_build_object('status', 'applied')
    );
  end if;

  if v_operation.status = 'failed' then
    return coalesce(
      v_operation.response,
      jsonb_build_object(
        'status', 'failed',
        'error_code', v_operation.error_code
      )
    );
  end if;

  with inserted as (
    insert into public.debts (
      id, group_id, title, principal_amount, due_date, notes, is_archived,
      created_at, updated_at, version
    )
    select
      (elem.value->>'id')::uuid,
      nullif(elem.value->>'group_id', '')::uuid,
      elem.value->>'title',
      (elem.value->>'principal_amount')::bigint,
      nullif(elem.value->>'due_date', '')::date,
      nullif(elem.value->>'notes', ''),
      coalesce((elem.value->>'is_archived')::boolean, false),
      coalesce(
        (elem.value->>'created_at')::timestamptz,
        pg_catalog.now()
      ),
      coalesce(
        (elem.value->>'updated_at')::timestamptz,
        pg_catalog.now()
      ),
      1
    from jsonb_array_elements(p_payload->'debts') as elem(value)
    returning id, version, updated_at
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', inserted.id,
        'version', inserted.version,
        'server_updated_at', inserted.updated_at
      )
      order by inserted.id
    ),
    '[]'::jsonb
  )
  into v_results
  from inserted;

  v_response := jsonb_build_object(
    'status', 'applied',
    'entity_type', 'debt_batch',
    'entity_id', p_entity_id,
    'count', v_count,
    'debts', v_results
  );

  perform public.complete_operation(
    p_operation_id, v_response, 'succeeded', null
  );

  perform public.append_audit_log(
    'admin',
    'sync.batch_create',
    'debt_batch',
    p_entity_id,
    p_operation_id,
    jsonb_build_object(
      'session_id', p_session_id,
      'device_id', p_device_id,
      'count', v_count
    )
  );

  return v_response;
end;
$function$;

revoke all on function public.admin_bulk_create_debts(
  uuid, uuid, jsonb, text, uuid, text
) from public, anon, authenticated;
grant execute on function public.admin_bulk_create_debts(
  uuid, uuid, jsonb, text, uuid, text
) to service_role;
