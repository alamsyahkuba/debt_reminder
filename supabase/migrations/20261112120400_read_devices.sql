-- Read-only device enrollment (Option A+).
--
-- An enrolled device receives an opaque, revocable token from an admin session.
-- The server stores only SHA-256(token). The token may be used only by the
-- read-only pull endpoint; it never grants mutation rights and anon still has
-- no access to public schema or tables.

create table public.read_devices (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  device_id text not null,
  token_hash text not null unique,
  created_by_session_id uuid
    references public.admin_sessions (id) on delete set null,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz,
  expires_at timestamptz not null,
  revoked_at timestamptz,
  constraint read_devices_name_length
    check (char_length(btrim(name)) between 1 and 100),
  constraint read_devices_device_id_length
    check (char_length(btrim(device_id)) between 1 and 200),
  constraint read_devices_token_hash_format
    check (token_hash ~ '^[0-9a-f]{64}$'),
  constraint read_devices_expiry_order
    check (expires_at > created_at),
  constraint read_devices_revocation_order
    check (revoked_at is null or revoked_at >= created_at)
);

comment on table public.read_devices is
  'Perangkat read-only yang di-enroll admin. Hanya token hash yang disimpan.';

-- A device may be re-enrolled after revocation, but only one active row per
-- device_id is allowed at a time.
create unique index read_devices_active_device_idx
  on public.read_devices (device_id)
  where revoked_at is null;

create index read_devices_active_expiry_idx
  on public.read_devices (expires_at)
  where revoked_at is null;

alter table public.read_devices enable row level security;

revoke all on table public.read_devices from anon;
revoke all on table public.read_devices from authenticated;
grant select, insert, update, delete on table public.read_devices to service_role;

comment on table public.read_devices is
  'RLS enabled. Option A+: admin-enrolled read-only devices only; no anon access.';
