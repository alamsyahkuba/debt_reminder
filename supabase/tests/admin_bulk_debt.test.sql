begin;

create extension if not exists pgtap with schema extensions;

select extensions.plan(15);

set local role service_role;

insert into public.debt_groups (id, name)
values ('70000000-0000-4000-8000-000000000001', 'Bulk group');

select extensions.is(
  (
    select public.admin_bulk_create_debts(
      '71000000-0000-4000-8000-000000000001'::uuid,
      '72000000-0000-4000-8000-000000000001'::uuid,
      jsonb_build_object(
        'id', '72000000-0000-4000-8000-000000000001',
        'debts', jsonb_build_array(
          jsonb_build_object(
            'id', '73000000-0000-4000-8000-000000000001',
            'group_id', '70000000-0000-4000-8000-000000000001',
            'title', 'Bulk satu',
            'principal_amount', 100000,
            'due_date', '2027-01-10',
            'notes', null,
            'is_archived', false,
            'created_at', '2026-11-14T10:00:00Z',
            'updated_at', '2026-11-14T10:00:00Z',
            'version', 1
          ),
          jsonb_build_object(
            'id', '73000000-0000-4000-8000-000000000002',
            'group_id', '70000000-0000-4000-8000-000000000001',
            'title', 'Bulk dua',
            'principal_amount', 200000,
            'due_date', null,
            'notes', 'Catatan',
            'is_archived', false,
            'created_at', '2026-11-14T10:00:00Z',
            'updated_at', '2026-11-14T10:00:00Z',
            'version', 1
          ),
          jsonb_build_object(
            'id', '73000000-0000-4000-8000-000000000003',
            'group_id', '70000000-0000-4000-8000-000000000001',
            'title', 'Bulk tiga',
            'principal_amount', 300000,
            'due_date', '2027-02-01',
            'notes', null,
            'is_archived', false,
            'created_at', '2026-11-14T10:00:00Z',
            'updated_at', '2026-11-14T10:00:00Z',
            'version', 1
          )
        )
      ),
      repeat('a', 64),
      '74000000-0000-4000-8000-000000000001'::uuid,
      'test-device'
    )->>'status'
  ),
  'applied',
  'bulk create applied'
);
select extensions.is(
  (
    select count(*)::integer
    from public.debts
    where id in (
      '73000000-0000-4000-8000-000000000001',
      '73000000-0000-4000-8000-000000000002',
      '73000000-0000-4000-8000-000000000003'
    )
  ),
  3,
  'all bulk rows inserted'
);
select extensions.is(
  (
    select count(*)::integer
    from public.debts
    where group_id = '70000000-0000-4000-8000-000000000001'
      and title like 'Bulk%'
  ),
  3,
  'all rows use the batch group'
);
select extensions.is(
  (
    select count(*)::integer
    from public.debts
    where id in (
      '73000000-0000-4000-8000-000000000001',
      '73000000-0000-4000-8000-000000000002',
      '73000000-0000-4000-8000-000000000003'
    )
      and version = 1
  ),
  3,
  'bulk rows start at version 1'
);
select extensions.is(
  (
    select (public.admin_bulk_create_debts(
      '71000000-0000-4000-8000-000000000001'::uuid,
      '72000000-0000-4000-8000-000000000001'::uuid,
      jsonb_build_object(
        'id', '72000000-0000-4000-8000-000000000001',
        'debts', jsonb_build_array(
          jsonb_build_object(
            'id', '73000000-0000-4000-8000-000000000001',
            'group_id', '70000000-0000-4000-8000-000000000001',
            'title', 'Bulk satu',
            'principal_amount', 100000,
            'due_date', '2027-01-10',
            'notes', null,
            'is_archived', false,
            'created_at', '2026-11-14T10:00:00Z',
            'updated_at', '2026-11-14T10:00:00Z',
            'version', 1
          ),
          jsonb_build_object(
            'id', '73000000-0000-4000-8000-000000000002',
            'group_id', '70000000-0000-4000-8000-000000000001',
            'title', 'Bulk dua',
            'principal_amount', 200000,
            'due_date', null,
            'notes', 'Catatan',
            'is_archived', false,
            'created_at', '2026-11-14T10:00:00Z',
            'updated_at', '2026-11-14T10:00:00Z',
            'version', 1
          ),
          jsonb_build_object(
            'id', '73000000-0000-4000-8000-000000000003',
            'group_id', '70000000-0000-4000-8000-000000000001',
            'title', 'Bulk tiga',
            'principal_amount', 300000,
            'due_date', '2027-02-01',
            'notes', null,
            'is_archived', false,
            'created_at', '2026-11-14T10:00:00Z',
            'updated_at', '2026-11-14T10:00:00Z',
            'version', 1
          )
        )
      ),
      repeat('a', 64),
      '74000000-0000-4000-8000-000000000001'::uuid,
      'test-device'
    )->>'count')::integer
  ),
  3,
  'replay returns the original count'
);
select extensions.is(
  (
    select count(*)::integer
    from public.debts
    where id in (
      '73000000-0000-4000-8000-000000000001',
      '73000000-0000-4000-8000-000000000002',
      '73000000-0000-4000-8000-000000000003'
    )
  ),
  3,
  'replay does not duplicate rows'
);
select extensions.is(
  (
    select status
    from public.operation_registry
    where operation_id = '71000000-0000-4000-8000-000000000001'::uuid
  ),
  'succeeded',
  'bulk operation is recorded as succeeded'
);
select extensions.ok(
  exists (
    select 1
    from public.audit_logs
    where action = 'sync.batch_create'
      and entity_id = '72000000-0000-4000-8000-000000000001'::uuid
  ),
  'bulk create appends an audit log'
);

select extensions.throws_ok(
  $sql$
    select public.admin_bulk_create_debts(
      '71000000-0000-4000-8000-000000000002'::uuid,
      '72000000-0000-4000-8000-000000000002'::uuid,
      jsonb_build_object(
        'id', '72000000-0000-4000-8000-000000000002',
        'debts', jsonb_build_array(
          jsonb_build_object(
            'id', '73000000-0000-4000-8000-000000000010',
            'title', 'Bulk invalid',
            'principal_amount', 0,
            'version', 1
          )
        )
      ),
      repeat('b', 64),
      '74000000-0000-4000-8000-000000000001'::uuid,
      'test-device'
    )
  $sql$,
  '23514',
  null,
  'invalid row rejects the whole batch'
);
select extensions.is(
  (
    select count(*)::integer
    from public.debts
    where id = '73000000-0000-4000-8000-000000000010'::uuid
  ),
  0,
  'invalid batch leaves no rows'
);
select extensions.throws_ok(
  $sql$
    select public.admin_bulk_create_debts(
      '71000000-0000-4000-8000-000000000003'::uuid,
      '72000000-0000-4000-8000-000000000003'::uuid,
      jsonb_build_object(
        'id', '72000000-0000-4000-8000-000000000003',
        'debts', jsonb_build_array(
          jsonb_build_object(
            'id', '73000000-0000-4000-8000-000000000011',
            'title', 'Bulk duplikat',
            'principal_amount', 1000,
            'version', 1
          ),
          jsonb_build_object(
            'id', '73000000-0000-4000-8000-000000000011',
            'title', 'Bulk duplikat lagi',
            'principal_amount', 2000,
            'version', 1
          )
        )
      ),
      repeat('c', 64),
      '74000000-0000-4000-8000-000000000001'::uuid,
      'test-device'
    )
  $sql$,
  'P0001',
  'ID hutang duplikat',
  'duplicate debt ids are rejected'
);
select extensions.throws_ok(
  $sql$
    select public.admin_bulk_create_debts(
      '71000000-0000-4000-8000-000000000004'::uuid,
      '72000000-0000-4000-8000-000000000004'::uuid,
      jsonb_build_object(
        'id', '72000000-0000-4000-8000-000000000004',
        'debts', (
          select jsonb_agg(
            jsonb_build_object(
              'id', format('73000001-0000-4000-8000-%s', lpad(i::text, 12, '0')),
              'title', 'Bulk terlalu banyak',
              'principal_amount', 1000,
              'version', 1
            )
          )
          from generate_series(1, 51) as i
        )
      ),
      repeat('d', 64),
      '74000000-0000-4000-8000-000000000001'::uuid,
      'test-device'
    )
  $sql$,
  '22023',
  null,
  'more than 50 rows is rejected'
);
select extensions.throws_ok(
  $sql$
    select public.admin_bulk_create_debts(
      '71000000-0000-4000-8000-000000000005'::uuid,
      '72000000-0000-4000-8000-000000000005'::uuid,
      jsonb_build_object(
        'id', '72000000-0000-4000-8000-000000000005',
        'debts', jsonb_build_array(
          jsonb_build_object(
            'id', '73000000-0000-4000-8000-000000000012',
            'group_id', '99999999-9999-4999-8999-999999999999',
            'title', 'Bulk group hilang',
            'principal_amount', 1000,
            'version', 1
          )
        )
      ),
      repeat('e', 64),
      '74000000-0000-4000-8000-000000000001'::uuid,
      'test-device'
    )
  $sql$,
  '23503',
  null,
  'missing group rejects the batch'
);
select extensions.ok(
  not has_function_privilege(
    'anon',
    'public.admin_bulk_create_debts(uuid, uuid, jsonb, text, uuid, text)',
    'execute'
  ),
  'anon cannot execute bulk create RPC'
);
select extensions.ok(
  has_function_privilege(
    'service_role',
    'public.admin_bulk_create_debts(uuid, uuid, jsonb, text, uuid, text)',
    'execute'
  ),
  'service role can execute bulk create RPC'
);

reset role;

select * from extensions.finish();
rollback;
