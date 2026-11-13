begin;

create extension if not exists pgtap with schema extensions;
select extensions.plan(26);

set local role service_role;

insert into public.debt_groups (id, name, description, color, icon, sort_order)
values (
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'Keluarga',
  'Group publik',
  '#00695C',
  'family',
  1
);

insert into public.debt_groups (id, name, sort_order, updated_at)
values (
  'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
  'Tetangga',
  2,
  pg_catalog.now() + interval '1 second'
);

insert into public.debts (
  id,
  group_id,
  title,
  principal_amount,
  due_date,
  notes
)
values (
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'Hutang publik',
  1000000,
  '2027-01-10',
  'Catatan publik'
);

insert into public.payments (id, debt_id, amount, operation_id, notes)
values (
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  250000,
  'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  'Pembayaran publik'
);

reset role;
set local role anon;

select extensions.ok(
  has_function_privilege('anon', 'public.public_debt_groups()', 'execute'),
  'anon dapat execute public_debt_groups'
);
select extensions.ok(
  has_function_privilege('anon', 'public.public_debts()', 'execute'),
  'anon dapat execute public_debts'
);
select extensions.ok(
  has_function_privilege('anon', 'public.public_payments()', 'execute'),
  'anon dapat execute public_payments'
);
select extensions.ok(
  has_function_privilege(
    'anon',
    'public.public_debt_groups_page(timestamptz, uuid, integer)',
    'execute'
  ),
  'anon dapat execute public_debt_groups_page'
);
select extensions.ok(
  has_function_privilege(
    'anon',
    'public.public_debts_page(timestamptz, uuid, integer)',
    'execute'
  ),
  'anon dapat execute public_debts_page'
);
select extensions.ok(
  has_function_privilege(
    'anon',
    'public.public_payments_page(timestamptz, uuid, integer)',
    'execute'
  ),
  'anon dapat execute public_payments_page'
);
select extensions.is(
  (select count(*)::integer from public.public_debt_groups()),
  2,
  'public_debt_groups mengembalikan group'
);
select extensions.is(
  (select count(*)::integer from public.public_debts()),
  1,
  'public_debts mengembalikan hutang'
);
select extensions.is(
  (select count(*)::integer from public.public_payments()),
  1,
  'public_payments mengembalikan pembayaran'
);
select extensions.is(
  (select status from public.public_debts()),
  'partial',
  'status hutang dihitung dari pembayaran'
);
select extensions.is(
  (select paid_amount from public.public_debts()),
  250000::bigint,
  'paid_amount publik benar'
);
select extensions.is(
  (select outstanding_amount from public.public_debts()),
  750000::bigint,
  'outstanding_amount publik benar'
);
select extensions.is(
  (select group_name from public.public_debts()),
  'Keluarga',
  'group_name publik tersedia'
);
select extensions.ok(
  not exists (
    select 1
    from public.public_debts() d
    where row_to_json(d)::jsonb ? 'version'
  ),
  'public_debts tidak membocorkan version'
);
select extensions.ok(
  not exists (
    select 1
    from public.public_debts() d
    where row_to_json(d)::jsonb ? 'operation_id'
  ),
  'public_debts tidak membocorkan operation_id'
);
select extensions.ok(
  not exists (
    select 1
    from public.public_payments() p
    where row_to_json(p)::jsonb ? 'operation_id'
  ),
  'public_payments tidak membocorkan operation_id'
);
select extensions.is(
  (
    select count(*)::integer
    from public.public_debt_groups_page(null, null, 1)
  ),
  1,
  'page group pertama mengembalikan satu baris'
);
select extensions.is(
  (
    select count(*)::integer
    from public.public_debt_groups_page(
      (select updated_at from public.public_debt_groups_page(null, null, 1)),
      (select id from public.public_debt_groups_page(null, null, 1)),
      10
    )
  ),
  1,
  'page group kedua memakai cursor keyset'
);
select extensions.is(
  (
    select count(*)::integer
    from public.public_debts_page(null, null, 10)
  ),
  1,
  'page hutang mengembalikan data'
);
select extensions.is(
  (
    select count(*)::integer
    from public.public_payments_page(null, null, 10)
  ),
  1,
  'page pembayaran mengembalikan data'
);
select extensions.throws_ok(
  $sql$select * from public.public_debt_groups_page(null, null, 0)$sql$,
  '22023',
  null,
  'limit page tidak valid ditolak'
);
select extensions.throws_ok(
  $sql$select * from public.public_debts_page(now(), null, 10)$sql$,
  '22023',
  null,
  'cursor page tidak lengkap ditolak'
);
select extensions.ok(
  not exists (
    select 1
    from public.public_debts_page(null, null, 10) d
    where row_to_json(d)::jsonb ? 'version'
  ),
  'page hutang tidak membocorkan version'
);

select extensions.throws_ok(
  $sql$select * from public.debt_groups$sql$,
  '42501',
  null,
  'anon tidak dapat select base debt_groups'
);
select extensions.throws_ok(
  $sql$insert into public.debts (title, principal_amount) values ('Anon', 1000)$sql$,
  '42501',
  null,
  'anon tidak dapat insert debts'
);
select extensions.throws_ok(
  $sql$select public.begin_operation('aaaaaaaa-1111-4111-8111-111111111111', 'debt.create', 'debt', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', repeat('a', 64))$sql$,
  '42501',
  null,
  'anon tidak dapat memanggil begin_operation'
);

reset role;

select * from extensions.finish();
rollback;
