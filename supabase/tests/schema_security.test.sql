begin;

create extension if not exists pgtap with schema extensions;

select extensions.plan(53);

-- ---------------------------------------------------------------------------
-- RLS is enabled on every table.
-- ---------------------------------------------------------------------------
select extensions.ok(
  (select relrowsecurity from pg_class where oid = 'public.debt_groups'::regclass),
  'RLS aktif pada debt_groups'
);
select extensions.ok(
  (select relrowsecurity from pg_class where oid = 'public.debts'::regclass),
  'RLS aktif pada debts'
);
select extensions.ok(
  (select relrowsecurity from pg_class where oid = 'public.payments'::regclass),
  'RLS aktif pada payments'
);
select extensions.ok(
  (select relrowsecurity from pg_class where oid = 'public.admin_settings'::regclass),
  'RLS aktif pada admin_settings'
);
select extensions.ok(
  (select relrowsecurity from pg_class where oid = 'public.audit_logs'::regclass),
  'RLS aktif pada audit_logs'
);
select extensions.ok(
  (select relrowsecurity from pg_class where oid = 'public.admin_sessions'::regclass),
  'RLS aktif pada admin_sessions'
);
select extensions.ok(
  (select relrowsecurity from pg_class where oid = 'public.operation_registry'::regclass),
  'RLS aktif pada operation_registry'
);

-- ---------------------------------------------------------------------------
-- Removed entities and public-read configuration.
-- ---------------------------------------------------------------------------
select extensions.ok(
  to_regclass('public.customers') is null,
  'Tabel customers sudah dihapus'
);
select extensions.ok(
  to_regclass('public.read_devices') is null,
  'Tabel read_devices sudah dihapus'
);
select extensions.hasnt_column(
  'public',
  'debts',
  'customer_id',
  'debts tidak memiliki customer_id'
);
select extensions.hasnt_column(
  'public',
  'debt_groups',
  'parent_id',
  'debt_groups tidak memiliki parent_id/subgroup'
);
select extensions.is(
  (
    select count(*)::integer
    from pg_policies
    where schemaname = 'public'
      and roles && array['anon', 'authenticated']::name[]
  ),
  0,
  'Tidak ada policy anon/authenticated pada base table'
);
select extensions.ok(
  has_schema_privilege('anon', 'public', 'usage'),
  'anon memiliki usage schema untuk public RPC'
);
select extensions.ok(
  not has_table_privilege('anon', 'public.debt_groups', 'select'),
  'anon tidak dapat select debt_groups'
);
select extensions.ok(
  not has_table_privilege('anon', 'public.debts', 'select'),
  'anon tidak dapat select debts'
);
select extensions.ok(
  not has_table_privilege('anon', 'public.payments', 'select'),
  'anon tidak dapat select payments'
);
select extensions.ok(
  not has_table_privilege('anon', 'public.admin_settings', 'select'),
  'anon tidak dapat select admin_settings'
);
select extensions.ok(
  not has_table_privilege('anon', 'public.audit_logs', 'select'),
  'anon tidak dapat select audit_logs'
);
select extensions.ok(
  not has_function_privilege(
    'anon',
    'public.begin_operation(uuid,text,text,uuid,text,text)',
    'execute'
  ),
  'anon tidak dapat memanggil begin_operation'
);
select extensions.ok(
  has_table_privilege('service_role', 'public.debt_groups', 'select'),
  'service_role dapat membaca debt_groups'
);
select extensions.ok(
  has_table_privilege('service_role', 'public.payments', 'insert'),
  'service_role dapat menambah payments'
);
select extensions.ok(
  not has_table_privilege('service_role', 'public.payments', 'update'),
  'service_role tidak memiliki grant update payments'
);
select extensions.ok(
  has_table_privilege('service_role', 'public.admin_settings', 'select'),
  'service_role dapat membaca admin_settings'
);

-- ---------------------------------------------------------------------------
-- Baseline data, without a customer entity.
-- ---------------------------------------------------------------------------
set local role service_role;

select extensions.lives_ok(
  $sql$
    insert into public.debt_groups (id, name, color, icon, sort_order)
    values (
      'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      'Keluarga',
      '#00695C',
      'family',
      1
    )
  $sql$,
  'service_role dapat membuat group'
);
select extensions.lives_ok(
  $sql$
    insert into public.debts (id, group_id, title, principal_amount)
    values (
      'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      'Hutang sembako',
      1000000
    )
  $sql$,
  'service_role dapat membuat hutang tanpa pelanggan'
);
select extensions.lives_ok(
  $sql$
    insert into public.payments (id, debt_id, amount, operation_id)
    values (
      'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
      'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      250000,
      'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'
    )
  $sql$,
  'service_role dapat menambah pembayaran'
);

reset role;

select extensions.throws_ok(
  $sql$
    insert into public.payments (id, debt_id, amount, operation_id)
    values (
      'dddddddd-dddd-4ddd-8ddd-dddddddddde1',
      'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      1000,
      'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'
    )
  $sql$,
  '23505',
  null,
  'operation_id pembayaran unik'
);
select extensions.throws_ok(
  $sql$
    insert into public.debts (title, principal_amount)
    values ('Nol', 0)
  $sql$,
  '23514',
  null,
  'principal_amount harus positif'
);
select extensions.throws_ok(
  $sql$
    insert into public.payments (debt_id, amount, operation_id)
    values (
      'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      0,
      'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1'
    )
  $sql$,
  '23514',
  null,
  'amount pembayaran harus positif'
);
select extensions.throws_ok(
  $sql$
    insert into public.debt_groups (name, color)
    values ('Warna salah', 'teal')
  $sql$,
  '23514',
  null,
  'color group harus hex tervalidasi'
);
select extensions.throws_ok(
  $sql$
    insert into public.debt_groups (name, icon)
    values ('Ikon salah', 'arbitrary_widget')
  $sql$,
  '23514',
  null,
  'icon group harus dari allowlist'
);

-- ---------------------------------------------------------------------------
-- Append-only guards.
-- ---------------------------------------------------------------------------
select extensions.throws_ok(
  $sql$update public.payments set amount = 1 where id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'$sql$,
  '23001',
  null,
  'pembayaran tidak dapat diubah'
);
select extensions.throws_ok(
  $sql$delete from public.payments where id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'$sql$,
  '23001',
  null,
  'pembayaran tidak dapat dihapus'
);

select extensions.lives_ok(
  $sql$
    insert into public.audit_logs (id, actor_type, action, entity_type)
    values ('ffffffff-ffff-4fff-8fff-ffffffffffff', 'admin', 'test', 'debt')
  $sql$,
  'audit log dapat ditambahkan'
);
select extensions.throws_ok(
  $sql$update public.audit_logs set action = 'changed' where id = 'ffffffff-ffff-4fff-8fff-ffffffffffff'$sql$,
  '23001',
  null,
  'audit log tidak dapat diubah'
);
select extensions.lives_ok(
  $sql$
    select public.append_audit_log(
      'admin',
      'debt.create',
      'debt',
      'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
      '{"source":"test"}'::jsonb
    )
  $sql$,
  'helper append_audit_log berfungsi'
);

-- ---------------------------------------------------------------------------
-- Versioning and approved relation behavior.
-- ---------------------------------------------------------------------------
select extensions.lives_ok(
  $sql$update public.debt_groups set description = 'Group keluarga' where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'$sql$,
  'group dapat diubah'
);
select extensions.is(
  (
    select version
    from public.debt_groups
    where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
  ),
  2::bigint,
  'version group naik saat update'
);
select extensions.lives_ok(
  $sql$update public.debts set group_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb' where id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc'$sql$,
  'hutang dapat dipindahkan ke group'
);
select extensions.lives_ok(
  $sql$delete from public.debt_groups where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'$sql$,
  'group dapat dihapus setelah konfirmasi aplikasi'
);
select extensions.is(
  (
    select group_id
    from public.debts
    where id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc'
  ),
  null::uuid,
  'hutang menjadi Unassigned saat group dihapus'
);
select extensions.throws_ok(
  $sql$delete from public.debts where id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc'$sql$,
  '23503',
  null,
  'hutang dengan pembayaran tidak dapat dihapus'
);

-- ---------------------------------------------------------------------------
-- Admin settings singleton.
-- ---------------------------------------------------------------------------
select extensions.throws_ok(
  $sql$
    insert into public.admin_settings (id, pin_hash, pin_hash_algorithm)
    values (
      '11111111-1111-4111-8111-111111111111',
      repeat('a', 64),
      'argon2id'
    )
  $sql$,
  '23514',
  null,
  'admin_settings hanya boleh satu baris dengan ID tetap'
);
select extensions.lives_ok(
  $sql$
    insert into public.admin_settings (pin_hash, pin_hash_algorithm)
    values (repeat('a', 64), 'argon2id')
  $sql$,
  'baris admin_settings dapat dibuat'
);
select extensions.throws_ok(
  $sql$
    insert into public.admin_settings (pin_hash, pin_hash_algorithm)
    values (repeat('b', 64), 'argon2id')
  $sql$,
  '23505',
  null,
  'baris admin_settings kedua ditolak'
);

-- ---------------------------------------------------------------------------
-- Anon and authenticated attempts.
-- ---------------------------------------------------------------------------
set local role anon;

select extensions.throws_ok(
  $sql$select * from public.debt_groups$sql$,
  '42501',
  null,
  'anon tidak dapat select debt_groups'
);
select extensions.throws_ok(
  $sql$insert into public.debt_groups (name) values ('Anon')$sql$,
  '42501',
  null,
  'anon tidak dapat insert debt_groups'
);
select extensions.throws_ok(
  $sql$update public.debt_groups set name = 'Anon'$sql$,
  '42501',
  null,
  'anon tidak dapat update debt_groups'
);
select extensions.throws_ok(
  $sql$delete from public.debt_groups$sql$,
  '42501',
  null,
  'anon tidak dapat delete debt_groups'
);
select extensions.throws_ok(
  $sql$select * from public.admin_settings$sql$,
  '42501',
  null,
  'anon tidak dapat select admin_settings'
);
select extensions.throws_ok(
  $sql$select * from public.audit_logs$sql$,
  '42501',
  null,
  'anon tidak dapat select audit_logs'
);

reset role;
set local role authenticated;

select extensions.throws_ok(
  $sql$select * from public.debt_groups$sql$,
  '42501',
  null,
  'authenticated tidak dapat select debt_groups'
);
select extensions.throws_ok(
  $sql$insert into public.debts (title, principal_amount) values ('Auth', 1000)$sql$,
  '42501',
  null,
  'authenticated tidak dapat insert debts'
);

reset role;

select * from extensions.finish();
rollback;
