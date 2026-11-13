begin;

create extension if not exists pgtap with schema extensions;

select extensions.plan(28);

set local role service_role;

-- ---------------------------------------------------------------------------
-- Group create, replay, update, and conflict.
-- ---------------------------------------------------------------------------
select extensions.is(
  (
    select public.admin_apply_mutation(
      '10000000-0000-4000-8000-000000000001'::uuid,
      'create',
      'debt_group',
      '20000000-0000-4000-8000-000000000001'::uuid,
      jsonb_build_object(
        'id', '20000000-0000-4000-8000-000000000001',
        'name', 'Keluarga',
        'description', 'Group',
        'color', '#00695C',
        'icon', 'family',
        'sort_order', 1,
        'is_archived', false,
        'created_at', '2026-11-13T10:00:00Z',
        'updated_at', '2026-11-13T10:00:00Z',
        'version', 1
      ),
      repeat('a', 64),
      '30000000-0000-4000-8000-000000000001'::uuid,
      'test-device'
    )->>'status'
  ),
  'applied',
  'group create applied'
);
select extensions.is(
  (
    select version::integer
    from public.debt_groups
    where id = '20000000-0000-4000-8000-000000000001'::uuid
  ),
  1,
  'group create starts at version 1'
);
select extensions.is(
  (
    select public.admin_apply_mutation(
      '10000000-0000-4000-8000-000000000001'::uuid,
      'create',
      'debt_group',
      '20000000-0000-4000-8000-000000000001'::uuid,
      jsonb_build_object(
        'id', '20000000-0000-4000-8000-000000000001',
        'name', 'Keluarga',
        'description', 'Group',
        'color', '#00695C',
        'icon', 'family',
        'sort_order', 1,
        'is_archived', false,
        'created_at', '2026-11-13T10:00:00Z',
        'updated_at', '2026-11-13T10:00:00Z',
        'version', 1
      ),
      repeat('a', 64),
      '30000000-0000-4000-8000-000000000001'::uuid,
      'test-device'
    )->>'status'
  ),
  'applied',
  'replayed operation returns prior response'
);
select extensions.is(
  (
    select count(*)::integer
    from public.debt_groups
    where id = '20000000-0000-4000-8000-000000000001'::uuid
  ),
  1,
  'replay does not duplicate the group'
);

select extensions.is(
  (
    select public.admin_apply_mutation(
      '10000000-0000-4000-8000-000000000002'::uuid,
      'update',
      'debt_group',
      '20000000-0000-4000-8000-000000000001'::uuid,
      jsonb_build_object(
        'id', '20000000-0000-4000-8000-000000000001',
        'expected_version', 1,
        'name', 'Keluarga Besar',
        'description', 'Group',
        'color', '#00695C',
        'icon', 'family',
        'sort_order', 1,
        'is_archived', false
      ),
      repeat('b', 64),
      '30000000-0000-4000-8000-000000000001'::uuid,
      'test-device'
    )->>'status'
  ),
  'applied',
  'group update applied'
);
select extensions.is(
  (
    select version::integer
    from public.debt_groups
    where id = '20000000-0000-4000-8000-000000000001'::uuid
  ),
  2,
  'group update increments version'
);
select extensions.is(
  (
    select public.admin_apply_mutation(
      '10000000-0000-4000-8000-000000000003'::uuid,
      'archive',
      'debt_group',
      '20000000-0000-4000-8000-000000000001'::uuid,
      jsonb_build_object(
        'id', '20000000-0000-4000-8000-000000000001',
        'expected_version', 1,
        'is_archived', true
      ),
      repeat('c', 64),
      '30000000-0000-4000-8000-000000000001'::uuid,
      'test-device'
    )->>'status'
  ),
  'conflict',
  'stale group update returns conflict'
);
select extensions.is(
  (
    select name
    from public.debt_groups
    where id = '20000000-0000-4000-8000-000000000001'::uuid
  ),
  'Keluarga Besar',
  'stale group update does not overwrite server data'
);
select extensions.is(
  (
    select status
    from public.operation_registry
    where operation_id = '10000000-0000-4000-8000-000000000003'::uuid
  ),
  'failed',
  'conflict operation is recorded as failed'
);

-- ---------------------------------------------------------------------------
-- Debt create/update and payment idempotency.
-- ---------------------------------------------------------------------------
select extensions.is(
  (
    select public.admin_apply_mutation(
      '10000000-0000-4000-8000-000000000004'::uuid,
      'create',
      'debt',
      '40000000-0000-4000-8000-000000000001'::uuid,
      jsonb_build_object(
        'id', '40000000-0000-4000-8000-000000000001',
        'group_id', '20000000-0000-4000-8000-000000000001',
        'title', 'Hutang Motor',
        'principal_amount', 1000000,
        'due_date', '2027-01-10',
        'notes', 'Catatan',
        'is_archived', false,
        'created_at', '2026-11-13T10:00:00Z',
        'updated_at', '2026-11-13T10:00:00Z',
        'version', 1
      ),
      repeat('d', 64),
      '30000000-0000-4000-8000-000000000001'::uuid,
      'test-device'
    )->>'status'
  ),
  'applied',
  'debt create applied'
);
select extensions.is(
  (
    select group_id
    from public.debts
    where id = '40000000-0000-4000-8000-000000000001'::uuid
  ),
  '20000000-0000-4000-8000-000000000001'::uuid,
  'debt references the group'
);
select extensions.is(
  (
    select public.admin_apply_mutation(
      '10000000-0000-4000-8000-000000000005'::uuid,
      'payment_create',
      'payment',
      '50000000-0000-4000-8000-000000000001'::uuid,
      jsonb_build_object(
        'id', '50000000-0000-4000-8000-000000000001',
        'debt_id', '40000000-0000-4000-8000-000000000001',
        'amount', 250000,
        'paid_at', '2026-11-13T10:05:00Z',
        'notes', 'Cicilan',
        'operation_id', '10000000-0000-4000-8000-000000000005',
        'created_at', '2026-11-13T10:05:00Z'
      ),
      repeat('e', 64),
      '30000000-0000-4000-8000-000000000001'::uuid,
      'test-device'
    )->>'status'
  ),
  'applied',
  'payment create applied'
);
select extensions.is(
  (
    select count(*)::integer
    from public.payments
    where debt_id = '40000000-0000-4000-8000-000000000001'::uuid
  ),
  1,
  'payment row created once'
);
select extensions.is(
  (
    select public.admin_apply_mutation(
      '10000000-0000-4000-8000-000000000005'::uuid,
      'payment_create',
      'payment',
      '50000000-0000-4000-8000-000000000001'::uuid,
      jsonb_build_object(
        'id', '50000000-0000-4000-8000-000000000001',
        'debt_id', '40000000-0000-4000-8000-000000000001',
        'amount', 250000,
        'paid_at', '2026-11-13T10:05:00Z',
        'notes', 'Cicilan',
        'operation_id', '10000000-0000-4000-8000-000000000005',
        'created_at', '2026-11-13T10:05:00Z'
      ),
      repeat('e', 64),
      '30000000-0000-4000-8000-000000000001'::uuid,
      'test-device'
    )->>'status'
  ),
  'applied',
  'payment replay returns prior response'
);
select extensions.is(
  (
    select count(*)::integer
    from public.payments
    where debt_id = '40000000-0000-4000-8000-000000000001'::uuid
  ),
  1,
  'payment replay does not duplicate'
);
select extensions.throws_ok(
  $sql$
    select public.admin_apply_mutation(
      '10000000-0000-4000-8000-000000000006'::uuid,
      'payment_create',
      'payment',
      '50000000-0000-4000-8000-000000000002'::uuid,
      jsonb_build_object(
        'id', '50000000-0000-4000-8000-000000000002',
        'debt_id', '40000000-0000-4000-8000-000000000001',
        'amount', 800000,
        'paid_at', '2026-11-13T10:06:00Z',
        'notes', null,
        'operation_id', '10000000-0000-4000-8000-000000000006',
        'created_at', '2026-11-13T10:06:00Z'
      ),
      repeat('f', 64),
      '30000000-0000-4000-8000-000000000001'::uuid,
      'test-device'
    )
  $sql$,
  'P0001',
  'Pembayaran melebihi sisa hutang.',
  'server rejects overpayment'
);
select extensions.is(
  (
    select count(*)::integer
    from public.payments
    where debt_id = '40000000-0000-4000-8000-000000000001'::uuid
  ),
  1,
  'rejected overpayment is not stored'
);
select extensions.is(
  (
    select count(*)::integer
    from public.operation_registry
    where operation_id = '10000000-0000-4000-8000-000000000006'::uuid
  ),
  0,
  'rejected overpayment does not leave a registry row'
);

select extensions.is(
  (
    select public.admin_apply_mutation(
      '10000000-0000-4000-8000-000000000007'::uuid,
      'update',
      'debt',
      '40000000-0000-4000-8000-000000000001'::uuid,
      jsonb_build_object(
        'id', '40000000-0000-4000-8000-000000000001',
        'expected_version', 1,
        'group_id', '20000000-0000-4000-8000-000000000001',
        'title', 'Hutang Motor Baru',
        'principal_amount', 1000000,
        'due_date', '2027-01-10',
        'notes', 'Catatan',
        'is_archived', false
      ),
      repeat('1', 64),
      '30000000-0000-4000-8000-000000000001'::uuid,
      'test-device'
    )->>'status'
  ),
  'applied',
  'debt update applied'
);
select extensions.is(
  (
    select version::integer
    from public.debts
    where id = '40000000-0000-4000-8000-000000000001'::uuid
  ),
  2,
  'debt update increments version'
);
select extensions.is(
  (
    select public.admin_apply_mutation(
      '10000000-0000-4000-8000-000000000008'::uuid,
      'archive',
      'debt',
      '40000000-0000-4000-8000-000000000001'::uuid,
      jsonb_build_object(
        'id', '40000000-0000-4000-8000-000000000001',
        'expected_version', 1,
        'is_archived', true
      ),
      repeat('2', 64),
      '30000000-0000-4000-8000-000000000001'::uuid,
      'test-device'
    )->>'server_version'
  ),
  '2',
  'stale debt update returns server version'
);

-- ---------------------------------------------------------------------------
-- Group delete policy and audit.
-- ---------------------------------------------------------------------------
select extensions.is(
  (
    select public.admin_apply_mutation(
      '10000000-0000-4000-8000-000000000009'::uuid,
      'delete',
      'debt_group',
      '20000000-0000-4000-8000-000000000001'::uuid,
      jsonb_build_object(
        'id', '20000000-0000-4000-8000-000000000001',
        'expected_version', 2,
        'move_debts_to_unassigned', true
      ),
      repeat('3', 64),
      '30000000-0000-4000-8000-000000000001'::uuid,
      'test-device'
    )->>'status'
  ),
  'applied',
  'group delete applied'
);
select extensions.is(
  (
    select count(*)::integer
    from public.debt_groups
    where id = '20000000-0000-4000-8000-000000000001'::uuid
  ),
  0,
  'group is removed after delete'
);
select extensions.is(
  (
    select group_id
    from public.debts
    where id = '40000000-0000-4000-8000-000000000001'::uuid
  ),
  null::uuid,
  'debt moves to Unassigned on group delete'
);
select extensions.ok(
  (select count(*) >= 5 from public.audit_logs),
  'admin mutations append audit logs'
);
select extensions.ok(
  not has_function_privilege(
    'anon',
    'public.admin_apply_mutation(uuid, text, text, uuid, jsonb, text, uuid, text)',
    'execute'
  ),
  'anon cannot execute admin mutation RPC'
);
select extensions.throws_ok(
  $sql$
    select public.admin_apply_mutation(
      '10000000-0000-4000-8000-000000000010'::uuid,
      'create',
      'debt_group',
      '20000000-0000-4000-8000-000000000010'::uuid,
      jsonb_build_object('id', '20000000-0000-4000-8000-000000000010', 'name', 'X'),
      repeat('4', 64),
      null,
      'test-device'
    )
  $sql$,
  '22023',
  'session_id tidak valid',
  'admin mutation requires a server session id'
);
select extensions.throws_ok(
  $sql$
    select public.admin_apply_mutation(
      '10000000-0000-4000-8000-000000000011'::uuid,
      'create',
      'unknown',
      '20000000-0000-4000-8000-000000000011'::uuid,
      jsonb_build_object('id', '20000000-0000-4000-8000-000000000011'),
      repeat('5', 64),
      '30000000-0000-4000-8000-000000000001'::uuid,
      'test-device'
    )
  $sql$,
  '22023',
  'entity_type tidak valid',
  'unknown entity type is rejected'
);

reset role;

select * from extensions.finish();
rollback;
