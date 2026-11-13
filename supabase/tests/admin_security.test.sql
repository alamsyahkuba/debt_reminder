begin;

create extension if not exists pgtap with schema extensions;

select extensions.plan(33);

set local role service_role;

-- ---------------------------------------------------------------------------
-- PIN bootstrap and attempt throttling.
-- ---------------------------------------------------------------------------
select extensions.is(
  (
    select allowed
    from public.begin_admin_pin_attempt(
      '2026-11-13T10:00:00Z'::timestamptz,
      5,
      900
    )
  ),
  true,
  'PIN attempt allowed when admin PIN is not configured yet'
);
select extensions.is(
  (
    select has_pin
    from public.begin_admin_pin_attempt(
      '2026-11-13T10:00:00Z'::timestamptz,
      5,
      900
    )
  ),
  false,
  'has_pin false before initial PIN setup'
);
select extensions.lives_ok(
  $sql$
    select public.set_admin_pin_hash(repeat('a', 64), 'pbkdf2_sha256')
  $sql$,
  'initial PIN hash can be stored'
);
select extensions.ok(
  exists(
    select 1
    from public.admin_settings
    where id = '00000000-0000-0000-0000-000000000001'::uuid
  ),
  'admin_settings contains the singleton row'
);

select public.begin_admin_pin_attempt(
  '2026-11-13T10:00:00Z'::timestamptz, 5, 900
);
select public.begin_admin_pin_attempt(
  '2026-11-13T10:00:01Z'::timestamptz, 5, 900
);
select public.begin_admin_pin_attempt(
  '2026-11-13T10:00:02Z'::timestamptz, 5, 900
);
select public.begin_admin_pin_attempt(
  '2026-11-13T10:00:03Z'::timestamptz, 5, 900
);

select extensions.is(
  (select failed_attempt_count from public.admin_settings),
  4,
  'four failed attempts are recorded'
);
select extensions.is(
  (
    select allowed
    from public.begin_admin_pin_attempt(
      '2026-11-13T10:00:04Z'::timestamptz,
      5,
      900
    )
  ),
  false,
  'fifth consecutive attempt is rejected'
);
select extensions.ok(
  (select locked_until is not null from public.admin_settings),
  'fifth consecutive attempt sets locked_until'
);
select extensions.is(
  (
    select allowed
    from public.begin_admin_pin_attempt(
      '2026-11-13T10:01:00Z'::timestamptz,
      5,
      900
    )
  ),
  false,
  'attempts during lockout are rejected'
);
select extensions.ok(
  (
    select retry_after_seconds > 0
    from public.begin_admin_pin_attempt(
      '2026-11-13T10:01:00Z'::timestamptz,
      5,
      900
    )
  ),
  'lockout response includes retry_after_seconds'
);
select extensions.is(
  (
    select allowed
    from public.begin_admin_pin_attempt(
      '2026-11-13T10:16:00Z'::timestamptz,
      5,
      900
    )
  ),
  true,
  'attempts are allowed again after lockout expires'
);
select extensions.is(
  (
    select failed_attempt_count
    from public.admin_settings
  ),
  1,
  'attempt counter restarts after lockout expires'
);

select public.reset_admin_pin_attempts();

select extensions.is(
  (select failed_attempt_count from public.admin_settings),
  0,
  'successful verification resets the attempt counter'
);
select extensions.ok(
  (select locked_until is null from public.admin_settings),
  'successful verification clears the lockout'
);
select extensions.lives_ok(
  $sql$
    select public.set_admin_pin_hash(repeat('c', 64), 'pbkdf2_sha256')
  $sql$,
  'PIN hash can be changed by the service role'
);

-- ---------------------------------------------------------------------------
-- Session lifecycle.
-- ---------------------------------------------------------------------------
select extensions.lives_ok(
  $sql$
    select public.create_admin_session(
      '11111111-1111-4111-8111-111111111111'::uuid,
      repeat('b', 64),
      'device-1',
      '2026-11-13T10:15:00Z'::timestamptz,
      '2026-11-13T10:00:00Z'::timestamptz
    )
  $sql$,
  'admin session can be created'
);
select extensions.is(
  (
    select count(*)::integer
    from public.admin_sessions
    where token_hash = repeat('b', 64)
  ),
  1,
  'session row stores the token hash'
);
select extensions.is(
  public.is_admin_session_active(
    repeat('b', 64),
    'device-1',
    '2026-11-13T10:10:00Z'::timestamptz
  ),
  true,
  'active session passes verification'
);
select extensions.is(
  public.is_admin_session_active(
    repeat('b', 64),
    'device-2',
    '2026-11-13T10:10:00Z'::timestamptz
  ),
  false,
  'session is bound to the device id'
);
select public.touch_admin_session(
  repeat('b', 64),
  '2026-11-13T10:10:00Z'::timestamptz
);
select extensions.is(
  (
    select last_used_at
    from public.admin_sessions
    where token_hash = repeat('b', 64)
  ),
  '2026-11-13T10:10:00Z'::timestamptz,
  'session touch records last_used_at'
);
select extensions.is(
  public.revoke_admin_session(
    repeat('b', 64),
    '2026-11-13T10:11:00Z'::timestamptz
  ),
  true,
  'session can be revoked'
);
select extensions.is(
  public.is_admin_session_active(
    repeat('b', 64),
    'device-1',
    '2026-11-13T10:12:00Z'::timestamptz
  ),
  false,
  'revoked session is rejected'
);
select extensions.is(
  public.revoke_admin_session(
    repeat('b', 64),
    '2026-11-13T10:12:00Z'::timestamptz
  ),
  false,
  'revoking the same session twice is safe'
);

select public.create_admin_session(
  '22222222-2222-4222-8222-222222222222'::uuid,
  repeat('d', 64),
  'device-1',
  '2026-11-13T10:15:00Z'::timestamptz,
  '2026-11-13T10:00:00Z'::timestamptz
);
select public.create_admin_session(
  '33333333-3333-4333-8333-333333333333'::uuid,
  repeat('e', 64),
  'device-2',
  '2026-11-13T10:15:00Z'::timestamptz,
  '2026-11-13T10:00:00Z'::timestamptz
);
select extensions.is(
  public.revoke_other_admin_sessions(
    repeat('c', 64),
    '2026-11-13T10:05:00Z'::timestamptz
  ),
  2,
  'changing PIN revokes other active sessions'
);
select extensions.is(
  public.is_admin_session_active(
    repeat('d', 64),
    'device-1',
    '2026-11-13T10:06:00Z'::timestamptz
  ),
  false,
  'other device session is inactive after revocation'
);
select extensions.is(
  public.is_admin_session_active(
    repeat('e', 64),
    'device-2',
    '2026-11-13T10:06:00Z'::timestamptz
  ),
  false,
  'second other device session is inactive after revocation'
);

select public.create_admin_session(
  '44444444-4444-4444-8444-444444444444'::uuid,
  repeat('f', 64),
  'device-1',
  '2026-11-13T10:15:00Z'::timestamptz,
  '2026-11-13T10:00:00Z'::timestamptz
);
select extensions.is(
  public.is_admin_session_active(
    repeat('f', 64),
    'device-1',
    '2026-11-13T10:16:00Z'::timestamptz
  ),
  false,
  'expired session is rejected'
);

-- ---------------------------------------------------------------------------
-- Input validation and privilege boundaries.
-- ---------------------------------------------------------------------------
select extensions.throws_ok(
  $sql$
    select public.create_admin_session(
      '55555555-5555-4555-8555-555555555555'::uuid,
      repeat('9', 64),
      'device-1',
      '2026-11-13T10:17:00Z'::timestamptz,
      '2026-11-13T10:00:00Z'::timestamptz
    )
  $sql$,
  '22023',
  'expiry sesi tidak valid',
  'session expiry longer than the allowed lifetime is rejected'
);
select extensions.throws_ok(
  $sql$
    select *
    from public.begin_admin_pin_attempt(
      '2026-11-13T10:00:00Z'::timestamptz,
      21,
      900
    )
  $sql$,
  '22023',
  'max_attempts tidak valid',
  'invalid attempt limits are rejected'
);
select extensions.ok(
  not has_function_privilege(
    'anon',
    'public.begin_admin_pin_attempt(timestamptz, integer, integer)',
    'execute'
  ),
  'anon cannot execute PIN rate-limit helper'
);
select extensions.ok(
  not has_function_privilege(
    'authenticated',
    'public.create_admin_session(uuid, text, text, timestamptz, timestamptz)',
    'execute'
  ),
  'authenticated cannot execute session helper'
);
select extensions.ok(
  not has_table_privilege('anon', 'public.admin_settings', 'select'),
  'anon cannot read admin_settings'
);
select extensions.ok(
  not has_table_privilege('anon', 'public.admin_sessions', 'select'),
  'anon cannot read admin_sessions'
);
select extensions.ok(
  has_function_privilege(
    'service_role',
    'public.begin_admin_pin_attempt(timestamptz, integer, integer)',
    'execute'
  ),
  'service_role can execute PIN rate-limit helper'
);

reset role;

select * from extensions.finish();
rollback;
