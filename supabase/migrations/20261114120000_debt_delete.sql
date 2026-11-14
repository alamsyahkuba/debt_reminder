-- Hard delete debt is a separate mutation because payments must remain
-- append-only. A debt with any payment cannot be deleted.
--
-- Callable only by the service role from the admin-sync Edge Function.

create or replace function public.admin_delete_debt(
  p_operation_id uuid,
  p_entity_id uuid,
  p_payload_hash text,
  p_expected_version bigint,
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
  v_debt public.debts;
  v_payment_count bigint;
  v_server_version bigint;
  v_server_updated_at timestamptz;
  v_server_row jsonb;
  v_response jsonb;
begin
  if p_operation_id is null or p_entity_id is null then
    raise exception using errcode = '22023', message = 'ID operasi tidak valid';
  end if;

  if p_expected_version is null or p_expected_version < 1 then
    raise exception using errcode = '22023', message = 'expected_version tidak valid';
  end if;

  if p_session_id is null then
    raise exception using errcode = '22023', message = 'session_id tidak valid';
  end if;

  if p_device_id is null
    or char_length(btrim(p_device_id)) not between 1 and 200 then
    raise exception using errcode = '22023', message = 'device_id tidak valid';
  end if;

  v_operation := public.begin_operation(
    p_operation_id,
    'delete',
    'debt',
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
      jsonb_build_object('status', 'failed', 'error_code', v_operation.error_code)
    );
  end if;

  select *
  into v_debt
  from public.debts
  where id = p_entity_id
  for update;

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

  if v_debt.version <> p_expected_version then
    select d.version, d.updated_at, to_jsonb(d)
    into v_server_version, v_server_updated_at, v_server_row
    from public.debts d
    where d.id = p_entity_id;

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

  select count(*)::bigint
  into v_payment_count
  from public.payments p
  where p.debt_id = p_entity_id;

  if v_payment_count > 0 then
    raise exception using
      errcode = 'P0001',
      message = 'Hutang dengan pembayaran tidak dapat dihapus.';
  end if;

  delete from public.debts
  where id = p_entity_id
    and version = p_expected_version;

  v_response := jsonb_build_object(
    'status', 'applied',
    'entity_type', 'debt',
    'entity_id', p_entity_id,
    'deleted', true
  );

  perform public.complete_operation(
    p_operation_id, v_response, 'succeeded', null
  );

  perform public.append_audit_log(
    'admin', 'sync.delete', 'debt', p_entity_id, p_operation_id,
    jsonb_build_object(
      'session_id', p_session_id,
      'device_id', p_device_id
    )
  );

  return v_response;
end;
$function$;

revoke all on function public.admin_delete_debt(
  uuid, uuid, text, bigint, uuid, text
) from public, anon, authenticated;
grant execute on function public.admin_delete_debt(
  uuid, uuid, text, bigint, uuid, text
) to service_role;
