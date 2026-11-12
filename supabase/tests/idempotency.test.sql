begin;

create extension if not exists pgtap with schema extensions;

select extensions.plan(23);

set local role service_role;

select extensions.lives_ok(
  $sql$
    select public.begin_operation(
      'aaaaaaaa-1111-4111-8111-111111111111',
      'debt.create',
      'debt',
      'cccccccc-3333-4333-8333-333333333333',
      repeat('a', 64)
    )
  $sql$,
  'operasi baru dapat diklaim'
);
select extensions.is(
  (
    select status
    from public.operation_registry
    where operation_id = 'aaaaaaaa-1111-4111-8111-111111111111'
  ),
  'processing',
  'status awal adalah processing'
);
select extensions.is(
  (
    select count(*)::integer
    from public.operation_registry
    where operation_id = 'aaaaaaaa-1111-4111-8111-111111111111'
  ),
  1,
  'claim hanya membuat satu baris'
);

select extensions.lives_ok(
  $sql$
    select public.begin_operation(
      'aaaaaaaa-1111-4111-8111-111111111111',
      'debt.create',
      'debt',
      'cccccccc-3333-4333-8333-333333333333',
      repeat('a', 64)
    )
  $sql$,
  'claim ulang dengan payload sama aman'
);
select extensions.is(
  (
    select count(*)::integer
    from public.operation_registry
    where operation_id = 'aaaaaaaa-1111-4111-8111-111111111111'
  ),
  1,
  'claim ulang tidak membuat baris baru'
);

select extensions.throws_ok(
  $sql$
    select public.begin_operation(
      'aaaaaaaa-1111-4111-8111-111111111111',
      'debt.create',
      'debt',
      'cccccccc-3333-4333-8333-333333333333',
      repeat('b', 64)
    )
  $sql$,
  'P0001',
  'operation_payload_mismatch',
  'payload berbeda dengan operation_id yang sama ditolak'
);
select extensions.throws_ok(
  $sql$
    select public.begin_operation(
      'aaaaaaaa-1111-4111-8111-111111111111',
      'debt.update',
      'debt',
      'cccccccc-3333-4333-8333-333333333333',
      repeat('a', 64)
    )
  $sql$,
  'P0001',
  'operation_metadata_mismatch',
  'metadata berbeda dengan operation_id yang sama ditolak'
);
select extensions.throws_ok(
  $sql$
    select public.begin_operation(
      'aaaaaaaa-1111-4111-8111-111111111111',
      'debt.create',
      'debt',
      'cccccccc-3333-4333-8333-333333333333',
      repeat('z', 64)
    )
  $sql$,
  '22023',
  null,
  'payload hash tidak valid ditolak'
);

select extensions.lives_ok(
  $sql$
    select public.complete_operation(
      'aaaaaaaa-1111-4111-8111-111111111111',
      '{"id":"debt-1"}'::jsonb
    )
  $sql$,
  'operasi dapat diselesaikan'
);
select extensions.is(
  (
    select status
    from public.operation_registry
    where operation_id = 'aaaaaaaa-1111-4111-8111-111111111111'
  ),
  'succeeded',
  'status akhir succeeded'
);
select extensions.is(
  (
    select response ->> 'id'
    from public.operation_registry
    where operation_id = 'aaaaaaaa-1111-4111-8111-111111111111'
  ),
  'debt-1',
  'response tersimpan'
);

select extensions.lives_ok(
  $sql$
    select public.begin_operation(
      'aaaaaaaa-1111-4111-8111-111111111111',
      'debt.create',
      'debt',
      'cccccccc-3333-4333-8333-333333333333',
      repeat('a', 64)
    )
  $sql$,
  'retry setelah selesai mengembalikan hasil lama'
);
select extensions.is(
  (
    select status
    from public.operation_registry
    where operation_id = 'aaaaaaaa-1111-4111-8111-111111111111'
  ),
  'succeeded',
  'replay tetap succeeded'
);
select extensions.is(
  (
    select response ->> 'id'
    from public.operation_registry
    where operation_id = 'aaaaaaaa-1111-4111-8111-111111111111'
  ),
  'debt-1',
  'replay mengembalikan response yang sama'
);

select extensions.lives_ok(
  $sql$
    select public.complete_operation(
      'aaaaaaaa-1111-4111-8111-111111111111',
      '{"id":"ignored"}'::jsonb
    )
  $sql$,
  'complete ulang tidak error'
);
select extensions.is(
  (
    select response ->> 'id'
    from public.operation_registry
    where operation_id = 'aaaaaaaa-1111-4111-8111-111111111111'
  ),
  'debt-1',
  'complete ulang tidak menimpa response lama'
);

select extensions.lives_ok(
  $sql$
    select public.begin_operation(
      'bbbbbbbb-2222-4222-8222-222222222222',
      'debt.update',
      'debt',
      'cccccccc-3333-4333-8333-333333333333',
      repeat('b', 64)
    )
  $sql$,
  'operasi kedua dapat diklaim'
);
select extensions.lives_ok(
  $sql$
    select public.fail_operation(
      'bbbbbbbb-2222-4222-8222-222222222222',
      'validation_error'
    )
  $sql$,
  'operasi kedua dapat digagalkan'
);
select extensions.is(
  (
    select status
    from public.operation_registry
    where operation_id = 'bbbbbbbb-2222-4222-8222-222222222222'
  ),
  'failed',
  'status akhir failed'
);
select extensions.is(
  (
    select error_code
    from public.operation_registry
    where operation_id = 'bbbbbbbb-2222-4222-8222-222222222222'
  ),
  'validation_error',
  'error code tersimpan'
);

select extensions.throws_ok(
  $sql$
    select public.complete_operation(
      'aaaaaaaa-1111-4111-8111-111111111111',
      null::jsonb,
      'succeeded'
    )
  $sql$,
  '22023',
  null,
  'succeeded tanpa response ditolak'
);
select extensions.throws_ok(
  $sql$
    select public.fail_operation(
      'aaaaaaaa-1111-4111-8111-111111111111',
      'late_failure'
    )
  $sql$,
  'P0001',
  'operation_already_completed',
  'hasil final tidak dapat diubah menjadi failed'
);
select extensions.throws_ok(
  $sql$
    select public.complete_operation(
      'dddddddd-4444-4444-8444-444444444444',
      '{"id":"missing"}'::jsonb
    )
  $sql$,
  'P0002',
  'operation_not_found',
  'operasi yang tidak ada ditolak'
);

reset role;

select * from extensions.finish();
rollback;
