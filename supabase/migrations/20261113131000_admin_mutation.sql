-- Atomic admin mutation endpoint for the outbox sync worker.
--
-- The Edge Function authenticates the admin session, validates the payload,
-- then calls this function with the service role. Idempotency, version checks,
-- entity mutation, and audit happen in one PostgreSQL transaction.

create or replace function public.admin_apply_mutation(
  p_operation_id uuid,
  p_operation text,
  p_entity_type text,
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
  v_version bigint;
  v_updated_at timestamptz;
  v_server_version bigint;
  v_server_updated_at timestamptz;
  v_server_row jsonb;
  v_expected bigint;
  v_moved integer;
  v_paid bigint;
  v_debt public.debts;
begin
  if p_operation_id is null or p_entity_id is null then
    raise exception using errcode = '22023', message = 'ID operasi tidak valid';
  end if;

  if p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    raise exception using errcode = '22023', message = 'payload tidak valid';
  end if;

  if p_session_id is null then
    raise exception using errcode = '22023', message = 'session_id tidak valid';
  end if;

  if p_device_id is null or char_length(btrim(p_device_id)) not between 1 and 200 then
    raise exception using errcode = '22023', message = 'device_id tidak valid';
  end if;

  if p_payload ? 'id'
    and (p_payload->>'id')::uuid is distinct from p_entity_id then
    raise exception using errcode = '22023', message = 'entity_id tidak konsisten';
  end if;

  v_operation := public.begin_operation(
    p_operation_id,
    p_operation,
    p_entity_type,
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

  if p_entity_type = 'debt_group' then
    if p_operation = 'create' then
      insert into public.debt_groups (
        id, name, description, color, icon, sort_order, is_archived,
        created_at, updated_at, version
      ) values (
        p_entity_id,
        p_payload->>'name',
        nullif(p_payload->>'description', ''),
        nullif(p_payload->>'color', ''),
        nullif(p_payload->>'icon', ''),
        coalesce((p_payload->>'sort_order')::integer, 0),
        coalesce((p_payload->>'is_archived')::boolean, false),
        coalesce((p_payload->>'created_at')::timestamptz, pg_catalog.now()),
        coalesce((p_payload->>'updated_at')::timestamptz, pg_catalog.now()),
        1
      )
      returning version, updated_at into v_version, v_updated_at;

      v_response := jsonb_build_object(
        'status', 'applied',
        'entity_type', 'debt_group',
        'entity_id', p_entity_id,
        'version', v_version,
        'server_updated_at', v_updated_at
      );

    elsif p_operation in ('update', 'archive') then
      v_expected := (p_payload->>'expected_version')::bigint;

      update public.debt_groups
      set
        name = coalesce(p_payload->>'name', name),
        description = case
          when p_operation = 'update' then nullif(p_payload->>'description', '')
          else description
        end,
        color = case
          when p_operation = 'update' then nullif(p_payload->>'color', '')
          else color
        end,
        icon = case
          when p_operation = 'update' then nullif(p_payload->>'icon', '')
          else icon
        end,
        sort_order = case
          when p_operation = 'update'
            then coalesce((p_payload->>'sort_order')::integer, sort_order)
          else sort_order
        end,
        is_archived = coalesce(
          (p_payload->>'is_archived')::boolean,
          is_archived
        )
      where id = p_entity_id
        and version = v_expected
      returning version, updated_at into v_version, v_updated_at;

      if not found then
        select g.version, g.updated_at, to_jsonb(g)
        into v_server_version, v_server_updated_at, v_server_row
        from public.debt_groups g
        where g.id = p_entity_id;

        if not found then
          v_response := jsonb_build_object(
            'status', 'not_found',
            'entity_type', 'debt_group',
            'entity_id', p_entity_id
          );
          perform public.complete_operation(
            p_operation_id, v_response, 'failed', 'not_found'
          );
          return v_response;
        end if;

        v_response := jsonb_build_object(
          'status', 'conflict',
          'entity_type', 'debt_group',
          'entity_id', p_entity_id,
          'server_version', v_server_version,
          'server_updated_at', v_server_updated_at,
          'server_row', v_server_row
        );
        perform public.complete_operation(
          p_operation_id, v_response, 'failed', 'version_conflict'
        );
        perform public.append_audit_log(
          'admin', 'sync.version_conflict', 'debt_group', p_entity_id,
          p_operation_id,
          jsonb_build_object(
            'session_id', p_session_id,
            'device_id', p_device_id,
            'server_version', v_server_version
          )
        );
        return v_response;
      end if;

      v_response := jsonb_build_object(
        'status', 'applied',
        'entity_type', 'debt_group',
        'entity_id', p_entity_id,
        'version', v_version,
        'server_updated_at', v_updated_at
      );

    elsif p_operation = 'delete' then
      v_expected := (p_payload->>'expected_version')::bigint;

      select g.version
      into v_server_version
      from public.debt_groups g
      where g.id = p_entity_id
      for update;

      if not found then
        v_response := jsonb_build_object(
          'status', 'not_found',
          'entity_type', 'debt_group',
          'entity_id', p_entity_id
        );
        perform public.complete_operation(
          p_operation_id, v_response, 'failed', 'not_found'
        );
        return v_response;
      end if;

      if v_server_version <> v_expected then
        select to_jsonb(g), g.updated_at
        into v_server_row, v_server_updated_at
        from public.debt_groups g
        where g.id = p_entity_id;

        v_response := jsonb_build_object(
          'status', 'conflict',
          'entity_type', 'debt_group',
          'entity_id', p_entity_id,
          'server_version', v_server_version,
          'server_updated_at', v_server_updated_at,
          'server_row', v_server_row
        );
        perform public.complete_operation(
          p_operation_id, v_response, 'failed', 'version_conflict'
        );
        perform public.append_audit_log(
          'admin', 'sync.version_conflict', 'debt_group', p_entity_id,
          p_operation_id,
          jsonb_build_object(
            'session_id', p_session_id,
            'device_id', p_device_id,
            'server_version', v_server_version
          )
        );
        return v_response;
      end if;

      update public.debts
      set group_id = null
      where group_id = p_entity_id;
      get diagnostics v_moved = row_count;

      delete from public.debt_groups
      where id = p_entity_id
        and version = v_expected;

      v_response := jsonb_build_object(
        'status', 'applied',
        'entity_type', 'debt_group',
        'entity_id', p_entity_id,
        'deleted', true,
        'moved_debts', v_moved
      );

    else
      raise exception using errcode = '22023', message = 'operasi group tidak valid';
    end if;

  elsif p_entity_type = 'debt' then
    if p_operation = 'create' then
      insert into public.debts (
        id, group_id, title, principal_amount, due_date, notes, is_archived,
        created_at, updated_at, version
      ) values (
        p_entity_id,
        nullif(p_payload->>'group_id', '')::uuid,
        p_payload->>'title',
        (p_payload->>'principal_amount')::bigint,
        nullif(p_payload->>'due_date', '')::date,
        nullif(p_payload->>'notes', ''),
        coalesce((p_payload->>'is_archived')::boolean, false),
        coalesce((p_payload->>'created_at')::timestamptz, pg_catalog.now()),
        coalesce((p_payload->>'updated_at')::timestamptz, pg_catalog.now()),
        1
      )
      returning version, updated_at into v_version, v_updated_at;

      v_response := jsonb_build_object(
        'status', 'applied',
        'entity_type', 'debt',
        'entity_id', p_entity_id,
        'version', v_version,
        'server_updated_at', v_updated_at
      );

    elsif p_operation in ('update', 'archive') then
      v_expected := (p_payload->>'expected_version')::bigint;

      update public.debts
      set
        group_id = case
          when p_operation = 'update'
            then nullif(p_payload->>'group_id', '')::uuid
          else group_id
        end,
        title = coalesce(p_payload->>'title', title),
        principal_amount = case
          when p_operation = 'update'
            then coalesce((p_payload->>'principal_amount')::bigint, principal_amount)
          else principal_amount
        end,
        due_date = case
          when p_operation = 'update'
            then nullif(p_payload->>'due_date', '')::date
          else due_date
        end,
        notes = case
          when p_operation = 'update' then nullif(p_payload->>'notes', '')
          else notes
        end,
        is_archived = coalesce(
          (p_payload->>'is_archived')::boolean,
          is_archived
        )
      where id = p_entity_id
        and version = v_expected
      returning version, updated_at into v_version, v_updated_at;

      if not found then
        select d.version, d.updated_at, to_jsonb(d)
        into v_server_version, v_server_updated_at, v_server_row
        from public.debts d
        where d.id = p_entity_id;

        if not found then
          v_response := jsonb_build_object(
            'status', 'not_found',
            'entity_type', 'debt',
            'entity_id', p_entity_id
          );
          perform public.complete_operation(
            p_operation_id, v_response, 'failed', 'not_found'
          );
          return v_response;
        end if;

        v_response := jsonb_build_object(
          'status', 'conflict',
          'entity_type', 'debt',
          'entity_id', p_entity_id,
          'server_version', v_server_version,
          'server_updated_at', v_server_updated_at,
          'server_row', v_server_row
        );
        perform public.complete_operation(
          p_operation_id, v_response, 'failed', 'version_conflict'
        );
        perform public.append_audit_log(
          'admin', 'sync.version_conflict', 'debt', p_entity_id,
          p_operation_id,
          jsonb_build_object(
            'session_id', p_session_id,
            'device_id', p_device_id,
            'server_version', v_server_version
          )
        );
        return v_response;
      end if;

      v_response := jsonb_build_object(
        'status', 'applied',
        'entity_type', 'debt',
        'entity_id', p_entity_id,
        'version', v_version,
        'server_updated_at', v_updated_at
      );

    else
      raise exception using errcode = '22023', message = 'operasi hutang tidak valid';
    end if;

  elsif p_entity_type = 'payment' then
    if p_operation <> 'payment_create' then
      raise exception using errcode = '22023', message = 'operasi pembayaran tidak valid';
    end if;

    if p_payload ? 'operation_id'
      and (p_payload->>'operation_id')::uuid <> p_operation_id then
      raise exception using errcode = '22023', message = 'operation_id tidak konsisten';
    end if;

    select *
    into v_debt
    from public.debts
    where id = (p_payload->>'debt_id')::uuid;

    if not found then
      v_response := jsonb_build_object(
        'status', 'not_found',
        'entity_type', 'payment',
        'entity_id', p_entity_id
      );
      perform public.complete_operation(
        p_operation_id, v_response, 'failed', 'not_found'
      );
      return v_response;
    end if;

    if v_debt.is_archived then
      raise exception using
        errcode = 'P0001',
        message = 'Pembayaran tidak dapat ditambahkan ke hutang yang diarsipkan.';
    end if;

    select coalesce(sum(p.amount), 0)::bigint
    into v_paid
    from public.payments p
    where p.debt_id = v_debt.id;

    if (p_payload->>'amount')::bigint <= 0
      or v_paid + (p_payload->>'amount')::bigint > v_debt.principal_amount then
      raise exception using
        errcode = 'P0001',
        message = 'Pembayaran melebihi sisa hutang.';
    end if;

    insert into public.payments (
      id, debt_id, amount, paid_at, notes, operation_id, created_at
    ) values (
      p_entity_id,
      v_debt.id,
      (p_payload->>'amount')::bigint,
      coalesce((p_payload->>'paid_at')::timestamptz, pg_catalog.now()),
      nullif(p_payload->>'notes', ''),
      p_operation_id,
      coalesce((p_payload->>'created_at')::timestamptz, pg_catalog.now())
    );

    v_response := jsonb_build_object(
      'status', 'applied',
      'entity_type', 'payment',
      'entity_id', p_entity_id,
      'created_at', (
        select p.created_at from public.payments p where p.id = p_entity_id
      )
    );

  else
    raise exception using errcode = '22023', message = 'entity_type tidak valid';
  end if;

  perform public.complete_operation(
    p_operation_id, v_response, 'succeeded', null
  );

  perform public.append_audit_log(
    'admin',
    'sync.' || p_operation,
    p_entity_type,
    p_entity_id,
    p_operation_id,
    jsonb_build_object(
      'session_id', p_session_id,
      'device_id', p_device_id
    )
  );

  return v_response;
end;
$function$;

revoke all on function public.admin_apply_mutation(
  uuid, text, text, uuid, jsonb, text, uuid, text
) from public, anon, authenticated;
grant execute on function public.admin_apply_mutation(
  uuid, text, text, uuid, jsonb, text, uuid, text
) to service_role;
