-- Business schema for the shared Debt Reminder database.
-- Money is stored as integer rupiah (bigint), never floating point.
-- All rows are managed by server-side admin functions; see the security migration.

create table public.customers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text,
  notes text,
  is_archived boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1,
  constraint customers_name_length
    check (char_length(btrim(name)) between 1 and 200),
  constraint customers_phone_length
    check (phone is null or char_length(phone) <= 40),
  constraint customers_notes_length
    check (notes is null or char_length(notes) <= 2000),
  constraint customers_version_positive check (version >= 1),
  constraint customers_timestamps_ordered check (updated_at >= created_at)
);

comment on table public.customers is
  'Pelanggan pemilik hutang. Akses hanya melalui Edge Function admin.';

create index customers_name_search_idx
  on public.customers (lower(name))
  where is_archived = false;

create index customers_sync_idx
  on public.customers (updated_at, id);

create table public.debt_groups (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  color text,
  icon text,
  sort_order integer not null default 0,
  is_archived boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1,
  constraint debt_groups_name_length
    check (char_length(btrim(name)) between 1 and 100),
  constraint debt_groups_description_length
    check (description is null or char_length(description) <= 1000),
  constraint debt_groups_color_format
    check (color is null or color ~ '^#[0-9A-Fa-f]{6}$'),
  constraint debt_groups_icon_allowlist
    check (
      icon is null or icon in (
        'folder',
        'home',
        'work',
        'shopping_bag',
        'directions_car',
        'school',
        'health_and_safety',
        'receipt',
        'savings',
        'handshake',
        'family',
        'business_center'
      )
    ),
  constraint debt_groups_sort_order_range
    check (sort_order between 0 and 1000000),
  constraint debt_groups_version_positive check (version >= 1),
  constraint debt_groups_timestamps_ordered check (updated_at >= created_at)
);

comment on table public.debt_groups is
  'Group hutang sederhana. Tidak ada parent_id/subgroup.';

create index debt_groups_active_sort_idx
  on public.debt_groups (sort_order, name)
  where is_archived = false;

create index debt_groups_sync_idx
  on public.debt_groups (updated_at, id);

create table public.debts (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null
    references public.customers (id) on delete restrict,
  group_id uuid
    references public.debt_groups (id) on delete set null,
  title text not null,
  principal_amount bigint not null,
  due_date date,
  notes text,
  is_archived boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1,
  constraint debts_title_length
    check (char_length(btrim(title)) between 1 and 200),
  constraint debts_principal_positive check (principal_amount > 0),
  constraint debts_principal_safe_integer
    check (principal_amount <= 9007199254740991),
  constraint debts_notes_length
    check (notes is null or char_length(notes) <= 2000),
  constraint debts_version_positive check (version >= 1),
  constraint debts_timestamps_ordered check (updated_at >= created_at)
);

comment on table public.debts is
  'Hutang pelanggan. group_id null berarti Unassigned.';

create index debts_customer_idx on public.debts (customer_id);
create index debts_group_idx
  on public.debts (group_id)
  where group_id is not null;

create index debts_due_date_idx
  on public.debts (due_date)
  where is_archived = false and due_date is not null;

create index debts_sync_idx on public.debts (updated_at, id);

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  debt_id uuid not null
    references public.debts (id) on delete restrict,
  amount bigint not null,
  paid_at timestamptz not null default now(),
  notes text,
  operation_id uuid not null unique,
  created_at timestamptz not null default now(),
  constraint payments_amount_positive check (amount > 0),
  constraint payments_amount_safe_integer check (amount <= 9007199254740991),
  constraint payments_notes_length
    check (notes is null or char_length(notes) <= 2000)
);

comment on table public.payments is
  'Pembayaran append-only. operation_id unik untuk idempotensi.';

create index payments_debt_paid_idx
  on public.payments (debt_id, paid_at);

create index payments_sync_idx
  on public.payments (created_at, id);

create table public.admin_settings (
  id uuid primary key default '00000000-0000-0000-0000-000000000001'::uuid,
  pin_hash text not null,
  pin_hash_algorithm text not null,
  pin_changed_at timestamptz,
  failed_attempt_count integer not null default 0,
  locked_until timestamptz,
  updated_at timestamptz not null default now(),
  constraint admin_settings_singleton
    check (id = '00000000-0000-0000-0000-000000000001'::uuid),
  constraint admin_settings_pin_hash_length
    check (char_length(pin_hash) between 32 and 512),
  constraint admin_settings_algorithm_length
    check (char_length(btrim(pin_hash_algorithm)) between 1 and 50),
  constraint admin_settings_failed_attempts
    check (failed_attempt_count >= 0)
);

comment on table public.admin_settings is
  'Satu baris pengaturan admin. PIN hash tidak boleh pernah dikirim ke client.';

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_type text not null,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  operation_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint audit_logs_actor_type
    check (actor_type in ('admin', 'system')),
  constraint audit_logs_action_length
    check (char_length(btrim(action)) between 1 and 100),
  constraint audit_logs_entity_type_length
    check (char_length(btrim(entity_type)) between 1 and 100),
  constraint audit_logs_metadata_object
    check (jsonb_typeof(metadata) = 'object'),
  constraint audit_logs_metadata_size
    check (pg_column_size(metadata) <= 8192)
);

comment on table public.audit_logs is
  'Audit append-only. Metadata harus allowlisted dan tidak memuat secret.';

create index audit_logs_created_idx
  on public.audit_logs (created_at desc, id);

create index audit_logs_entity_idx
  on public.audit_logs (entity_type, entity_id);

create index audit_logs_operation_idx
  on public.audit_logs (operation_id)
  where operation_id is not null;

create table public.admin_sessions (
  id uuid primary key default gen_random_uuid(),
  token_hash text not null unique,
  device_id text not null,
  issued_at timestamptz not null default now(),
  expires_at timestamptz not null,
  revoked_at timestamptz,
  last_used_at timestamptz,
  created_at timestamptz not null default now(),
  constraint admin_sessions_token_hash_format
    check (token_hash ~ '^[0-9a-f]{64}$'),
  constraint admin_sessions_device_id_length
    check (char_length(btrim(device_id)) between 1 and 200),
  constraint admin_sessions_expiry_order
    check (expires_at > issued_at),
  constraint admin_sessions_revocation_order
    check (revoked_at is null or revoked_at >= issued_at)
);

comment on table public.admin_sessions is
  'Sesi admin server-side. token_hash adalah SHA-256 hex dari token.';

create index admin_sessions_active_idx
  on public.admin_sessions (expires_at)
  where revoked_at is null;

create table public.operation_registry (
  operation_id uuid primary key,
  actor_type text not null default 'admin',
  operation text not null,
  entity_type text not null,
  entity_id uuid,
  payload_hash text not null,
  status text not null default 'processing',
  response jsonb,
  error_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz,
  constraint operation_registry_actor_type
    check (actor_type in ('admin', 'system')),
  constraint operation_registry_operation_length
    check (char_length(btrim(operation)) between 1 and 100),
  constraint operation_registry_entity_type_length
    check (char_length(btrim(entity_type)) between 1 and 100),
  constraint operation_registry_payload_hash_format
    check (payload_hash ~ '^[0-9a-f]{64}$'),
  constraint operation_registry_status
    check (status in ('processing', 'succeeded', 'failed')),
  constraint operation_registry_error_code_length
    check (error_code is null or char_length(error_code) <= 100)
);

comment on table public.operation_registry is
  'Registry idempotensi server-side. Payload asli tidak disimpan, hanya hash.';

create index operation_registry_status_idx
  on public.operation_registry (status, created_at);

create index operation_registry_entity_idx
  on public.operation_registry (entity_type, entity_id);

create trigger customers_set_updated_at_and_version
before update on public.customers
for each row execute function private.set_updated_at_and_version();

create trigger debt_groups_set_updated_at_and_version
before update on public.debt_groups
for each row execute function private.set_updated_at_and_version();

create trigger debts_set_updated_at_and_version
before update on public.debts
for each row execute function private.set_updated_at_and_version();

create trigger admin_settings_set_updated_at
before update on public.admin_settings
for each row execute function private.set_updated_at();

create trigger operation_registry_set_updated_at
before update on public.operation_registry
for each row execute function private.set_updated_at();

create trigger payments_reject_mutation
before update or delete on public.payments
for each row execute function private.reject_mutation();

create trigger audit_logs_reject_mutation
before update or delete on public.audit_logs
for each row execute function private.reject_mutation();
