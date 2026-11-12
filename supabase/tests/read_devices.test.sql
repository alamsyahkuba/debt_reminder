begin;

create extension if not exists pgtap with schema extensions;

select extensions.plan(15);

select extensions.ok(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.read_devices'::regclass
  ),
  'RLS aktif pada read_devices'
);

select extensions.is(
  (
    select count(*)::integer
    from pg_policies
    where schemaname = 'public'
      and tablename = 'read_devices'
      and roles && array['anon', 'authenticated']::name[]
  ),
  0,
  'Tidak ada policy anon/authenticated pada read_devices'
);

select extensions.ok(
  has_table_privilege('service_role', 'public.read_devices', 'select'),
  'service_role dapat membaca read_devices'
);
select extensions.ok(
  not has_table_privilege('anon', 'public.read_devices', 'select'),
  'anon tidak memiliki grant read_devices'
);

set local role service_role;

select extensions.lives_ok(
  $sql$
    insert into public.read_devices (
      id,
      name,
      device_id,
      token_hash,
      expires_at
    ) values (
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      'HP keluarga',
      'device-1',
      repeat('a', 64),
      now() + interval '180 days'
    )
  $sql$,
  'service_role dapat mendaftarkan perangkat read-only'
);

select extensions.throws_ok(
  $sql$
    insert into public.read_devices (
      name,
      device_id,
      token_hash,
      expires_at
    ) values (
      'HP lain',
      'device-2',
      repeat('a', 64),
      now() + interval '180 days'
    )
  $sql$,
  '23505',
  null,
  'token hash perangkat harus unik'
);

select extensions.throws_ok(
  $sql$
    insert into public.read_devices (
      name,
      device_id,
      token_hash,
      expires_at
    ) values (
      'Token salah',
      'device-3',
      repeat('Z', 64),
      now() + interval '180 days'
    )
  $sql$,
  '23514',
  null,
  'token hash harus SHA-256 hex lowercase'
);

select extensions.throws_ok(
  $sql$
    insert into public.read_devices (
      name,
      device_id,
      token_hash,
      expires_at
    ) values (
      'Kedaluwarsa',
      'device-4',
      repeat('b', 64),
      '2000-01-01T00:00:00Z'::timestamptz
    )
  $sql$,
  '23514',
  null,
  'expires_at harus setelah created_at'
);

select extensions.throws_ok(
  $sql$
    insert into public.read_devices (
      name,
      device_id,
      token_hash,
      expires_at
    ) values (
      'HP kedua',
      'device-1',
      repeat('c', 64),
      now() + interval '180 days'
    )
  $sql$,
  '23505',
  null,
  'satu device_id hanya boleh punya satu enrollment aktif'
);

select extensions.lives_ok(
  $sql$
    update public.read_devices
    set revoked_at = now()
    where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
  $sql$,
  'perangkat read-only dapat dicabut'
);
select extensions.lives_ok(
  $sql$
    insert into public.read_devices (
      name,
      device_id,
      token_hash,
      expires_at
    ) values (
      'HP keluarga (baru)',
      'device-1',
      repeat('d', 64),
      now() + interval '180 days'
    )
  $sql$,
  'perangkat yang dicabut dapat di-enroll ulang'
);
select extensions.is(
  (
    select count(*)::integer
    from public.read_devices
    where device_id = 'device-1'
      and revoked_at is null
  ),
  1,
  'hanya satu enrollment aktif untuk device-1'
);

reset role;

set local role anon;
select extensions.throws_ok(
  $sql$select * from public.read_devices$sql$,
  '42501',
  null,
  'anon tidak dapat membaca read_devices'
);
select extensions.throws_ok(
  $sql$
    insert into public.read_devices (
      name,
      device_id,
      token_hash,
      expires_at
    ) values (
      'Anon',
      'device-anon',
      repeat('e', 64),
      now() + interval '180 days'
    )
  $sql$,
  '42501',
  null,
  'anon tidak dapat mendaftarkan perangkat'
);
reset role;

set local role authenticated;
select extensions.throws_ok(
  $sql$select * from public.read_devices$sql$,
  '42501',
  null,
  'authenticated tidak dapat membaca read_devices'
);
reset role;

select * from extensions.finish();
rollback;
