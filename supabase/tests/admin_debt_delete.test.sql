begin;

create extension if not exists pgtap with schema extensions;

select extensions.plan(12);

set local role service_role;

insert into public.debts (
  id, title, principal_amount, due_date, version
) values (
  'd1000000-0000-4000-8000-000000000001',
  'Hutang tanpa pembayaran',
  100000,
  '2027-01-10',
  1
);

select extensions.is(
  (
    select public.admin_delete_debt(
      'e1000000-0000-4000-8000-000000000001'::uuid,
      'd1000000-0000-4000-8000-000000000001'::uuid,
      repeat('a', 64),
      1,
      'f1000000-0000-4000-8000-000000000001'::uuid,
      'test-device'
    )->>'status'
  ),
  'applied',
  'debt tanpa payment dapat dihapus'
);
select extensions.is(
  (
    select count(*)::integer
    from public.debts
    where id = 'd1000000-0000-4000-8000-000000000001'::uuid
  ),
  0,
  'baris debt terhapus'
);
select extensions.is(
  (
    select public.admin_delete_debt(
      'e1000000-0000-4000-8000-000000000001'::uuid,
      'd1000000-0000-4000-8000-000000000001'::uuid,
      repeat('a', 64),
      1,
      'f1000000-0000-4000-8000-000000000001'::uuid,
      'test-device'
    )->>'status'
  ),
  'applied',
  'replay delete mengembalikan hasil lama'
);
select extensions.ok(
  (
    select count(*) > 0
    from public.audit_logs
    where action = 'sync.delete'
      and entity_id = 'd1000000-0000-4000-8000-000000000001'::uuid
  ),
  'hard delete dicatat di audit'
);

insert into public.debts (
  id, title, principal_amount, due_date, version
) values (
  'd1000000-0000-4000-8000-000000000002',
  'Hutang dengan pembayaran',
  100000,
  '2027-01-10',
  1
);
insert into public.payments (
  id, debt_id, amount, operation_id
) values (
  'd2000000-0000-4000-8000-000000000001',
  'd1000000-0000-4000-8000-000000000002',
  10000,
  'e2000000-0000-4000-8000-000000000001'
);

select extensions.throws_ok(
  $sql$
    select public.admin_delete_debt(
      'e1000000-0000-4000-8000-000000000002'::uuid,
      'd1000000-0000-4000-8000-000000000002'::uuid,
      repeat('b', 64),
      1,
      'f1000000-0000-4000-8000-000000000001'::uuid,
      'test-device'
    )
  $sql$,
  'P0001',
  'Hutang dengan pembayaran tidak dapat dihapus.',
  'debt dengan payment tidak dapat dihapus'
);
select extensions.is(
  (
    select count(*)::integer
    from public.debts
    where id = 'd1000000-0000-4000-8000-000000000002'::uuid
  ),
  1,
  'debt dengan payment tetap ada'
);
select extensions.is(
  (
    select count(*)::integer
    from public.payments
    where debt_id = 'd1000000-0000-4000-8000-000000000002'::uuid
  ),
  1,
  'payment tetap ada'
);

insert into public.debts (
  id, title, principal_amount, due_date, version
) values (
  'd1000000-0000-4000-8000-000000000003',
  'Hutang stale',
  100000,
  '2027-01-10',
  1
);

select extensions.is(
  (
    select public.admin_delete_debt(
      'e1000000-0000-4000-8000-000000000003'::uuid,
      'd1000000-0000-4000-8000-000000000003'::uuid,
      repeat('c', 64),
      99,
      'f1000000-0000-4000-8000-000000000001'::uuid,
      'test-device'
    )->>'status'
  ),
  'conflict',
  'stale version menghasilkan conflict'
);
select extensions.is(
  (
    select count(*)::integer
    from public.debts
    where id = 'd1000000-0000-4000-8000-000000000003'::uuid
  ),
  1,
  'debt stale tidak terhapus'
);

select extensions.is(
  (
    select public.admin_delete_debt(
      'e1000000-0000-4000-8000-000000000004'::uuid,
      'd1000000-0000-4000-8000-000000000099'::uuid,
      repeat('d', 64),
      1,
      'f1000000-0000-4000-8000-000000000001'::uuid,
      'test-device'
    )->>'status'
  ),
  'not_found',
  'debt yang tidak ada menghasilkan not_found'
);
select extensions.ok(
  not has_function_privilege(
    'anon',
    'public.admin_delete_debt(uuid, uuid, text, bigint, uuid, text)',
    'execute'
  ),
  'anon tidak dapat memanggil hard delete'
);
select extensions.ok(
  has_function_privilege(
    'service_role',
    'public.admin_delete_debt(uuid, uuid, text, bigint, uuid, text)',
    'execute'
  ),
  'service_role dapat memanggil hard delete'
);

reset role;

select * from extensions.finish();
rollback;
