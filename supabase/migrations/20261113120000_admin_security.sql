-- Admin PIN and session server-side helpers (Sprint 06).
--
-- PIN hashing and token signing happen in the Edge Function. These helpers
-- make rate limiting, session checks, and session revocation atomic in
-- PostgreSQL and keep internal tables service-role only.

-- The singleton starts uninitialized so rate limiting applies during bootstrap.
-- The handler treats the "uninitialized" algorithm as "PIN not configured".
insert into public.admin_settings (
  id,
  pin_hash,
  pin_hash_algorithm,
  pin_changed_at
) values (
  '00000000-0000-0000-0000-000000000001'::uuid,
  repeat('0', 64),
  'uninitialized',
  null
)
on conflict (id) do nothing;

create or replace function public.begin_admin_pin_attempt(
  p_now timestamptz,
  p_max_attempts integer,
  p_lock_seconds integer
)
returns table (
  allowed boolean,
  has_pin boolean,
  retry_after_seconds integer,
  failed_attempt_count integer
)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_row public.admin_settings;
  v_attempts integer;
  v_lock_until timestamptz;
begin
  if p_now is null then
    raise exception using errcode = '22023', message = 'waktu tidak valid';
  end if;

  if p_max_attempts not between 1 and 20 then
    raise exception using errcode = '22023', message = 'max_attempts tidak valid';
  end if;

  if p_lock_seconds not between 30 and 86400 then
    raise exception using errcode = '22023', message = 'lock_seconds tidak valid';
  end if;

  select *
  into v_row
  from public.admin_settings
  where id = '00000000-0000-0000-0000-000000000001'::uuid
  for update;

  if not found then
    return query select true, false, 0, 0;
    return;
  end if;

  if v_row.locked_until is not null and v_row.locked_until > p_now then
    return query
      select
        false,
        v_row.pin_hash_algorithm <> 'uninitialized',
        greatest(
          1,
          pg_catalog.ceil(
            pg_catalog.date_part('epoch', v_row.locked_until - p_now)
          )::integer
        ),
        v_row.failed_attempt_count;
    return;
  end if;

  v_attempts := case
    when v_row.locked_until is not null then 1
    else v_row.failed_attempt_count + 1
  end;

  if v_attempts >= p_max_attempts then
    v_lock_until := p_now + pg_catalog.make_interval(secs => p_lock_seconds);

    update public.admin_settings
    set
      failed_attempt_count = v_attempts,
      locked_until = v_lock_until,
      updated_at = p_now
    where id = v_row.id;

    return query select false, v_row.pin_hash_algorithm <> 'uninitialized', p_lock_seconds, v_attempts;
    return;
  end if;

  update public.admin_settings
  set
    failed_attempt_count = v_attempts,
    locked_until = null,
    updated_at = p_now
  where id = v_row.id;

  return query select true, v_row.pin_hash_algorithm <> 'uninitialized', 0, v_attempts;
end;
$function$;

create or replace function public.reset_admin_pin_attempts()
returns void
language sql
security definer
set search_path = ''
as $function$
  update public.admin_settings
  set
    failed_attempt_count = 0,
    locked_until = null,
    updated_at = pg_catalog.now()
  where id = '00000000-0000-0000-0000-000000000001'::uuid;
$function$;

create or replace function public.set_admin_pin_hash(
  p_pin_hash text,
  p_algorithm text
)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if p_pin_hash is null or char_length(p_pin_hash) not between 32 and 512 then
    raise exception using errcode = '22023', message = 'pin_hash tidak valid';
  end if;

  if p_algorithm is null
    or char_length(btrim(p_algorithm)) not between 1 and 50 then
    raise exception using errcode = '22023', message = 'algoritma pin tidak valid';
  end if;

  insert into public.admin_settings (
    id,
    pin_hash,
    pin_hash_algorithm,
    pin_changed_at,
    failed_attempt_count,
    locked_until,
    updated_at
  ) values (
    '00000000-0000-0000-0000-000000000001'::uuid,
    p_pin_hash,
    btrim(p_algorithm),
    pg_catalog.now(),
    0,
    null,
    pg_catalog.now()
  )
  on conflict (id) do update
  set
    pin_hash = excluded.pin_hash,
    pin_hash_algorithm = excluded.pin_hash_algorithm,
    pin_changed_at = excluded.pin_changed_at,
    failed_attempt_count = 0,
    locked_until = null,
    updated_at = excluded.updated_at;
end;
$function$;

create or replace function public.create_admin_session(
  p_session_id uuid,
  p_token_hash text,
  p_device_id text,
  p_expires_at timestamptz,
  p_now timestamptz
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if p_session_id is null then
    raise exception using errcode = '22023', message = 'session_id tidak valid';
  end if;

  if p_token_hash is null or p_token_hash !~ '^[0-9a-f]{64}$' then
    raise exception using errcode = '22023', message = 'token_hash tidak valid';
  end if;

  if p_device_id is null
    or char_length(btrim(p_device_id)) not between 1 and 200 then
    raise exception using errcode = '22023', message = 'device_id tidak valid';
  end if;

  if p_now is null then
    raise exception using errcode = '22023', message = 'waktu tidak valid';
  end if;

  if p_expires_at is null
    or p_expires_at <= p_now
    or p_expires_at > p_now + pg_catalog.make_interval(mins => 16) then
    raise exception using errcode = '22023', message = 'expiry sesi tidak valid';
  end if;

  insert into public.admin_sessions (
    id,
    token_hash,
    device_id,
    issued_at,
    expires_at,
    created_at
  ) values (
    p_session_id,
    p_token_hash,
    btrim(p_device_id),
    p_now,
    p_expires_at,
    p_now
  );

  return p_session_id;
end;
$function$;

create or replace function public.is_admin_session_active(
  p_token_hash text,
  p_device_id text,
  p_now timestamptz
)
returns boolean
language sql
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from public.admin_sessions
    where token_hash = p_token_hash
      and device_id = p_device_id
      and revoked_at is null
      and expires_at > p_now
  );
$function$;

create or replace function public.touch_admin_session(
  p_token_hash text,
  p_now timestamptz
)
returns void
language sql
security definer
set search_path = ''
as $function$
  update public.admin_sessions
  set last_used_at = p_now
  where token_hash = p_token_hash
    and revoked_at is null
    and expires_at > p_now;
$function$;

create or replace function public.revoke_admin_session(
  p_token_hash text,
  p_now timestamptz
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
begin
  update public.admin_sessions
  set revoked_at = p_now
  where token_hash = p_token_hash
    and revoked_at is null
    and expires_at > p_now;

  return found;
end;
$function$;

create or replace function public.revoke_other_admin_sessions(
  p_token_hash text,
  p_now timestamptz
)
returns integer
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_count integer;
begin
  update public.admin_sessions
  set revoked_at = p_now
  where token_hash <> p_token_hash
    and revoked_at is null
    and expires_at > p_now;

  get diagnostics v_count = row_count;
  return v_count;
end;
$function$;

revoke all on function public.begin_admin_pin_attempt(timestamptz, integer, integer)
  from public, anon, authenticated;
revoke all on function public.reset_admin_pin_attempts() from public, anon, authenticated;
revoke all on function public.set_admin_pin_hash(text, text)
  from public, anon, authenticated;
revoke all on function public.create_admin_session(uuid, text, text, timestamptz, timestamptz)
  from public, anon, authenticated;
revoke all on function public.is_admin_session_active(text, text, timestamptz)
  from public, anon, authenticated;
revoke all on function public.touch_admin_session(text, timestamptz)
  from public, anon, authenticated;
revoke all on function public.revoke_admin_session(text, timestamptz)
  from public, anon, authenticated;
revoke all on function public.revoke_other_admin_sessions(text, timestamptz)
  from public, anon, authenticated;

grant execute on function public.begin_admin_pin_attempt(timestamptz, integer, integer)
  to service_role;
grant execute on function public.reset_admin_pin_attempts() to service_role;
grant execute on function public.set_admin_pin_hash(text, text) to service_role;
grant execute on function public.create_admin_session(uuid, text, text, timestamptz, timestamptz)
  to service_role;
grant execute on function public.is_admin_session_active(text, text, timestamptz)
  to service_role;
grant execute on function public.touch_admin_session(text, timestamptz)
  to service_role;
grant execute on function public.revoke_admin_session(text, timestamptz)
  to service_role;
grant execute on function public.revoke_other_admin_sessions(text, timestamptz)
  to service_role;
