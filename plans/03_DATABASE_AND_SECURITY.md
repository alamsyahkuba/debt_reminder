# Database & Security

## 1. Cloud schema

### `customers`
- `id uuid primary key`
- `name text not null`
- `phone text null`
- `notes text null`
- `is_archived boolean not null default false`
- `created_at timestamptz not null`
- `updated_at timestamptz not null`
- `version bigint not null default 1`

### `debt_groups`
- `id uuid primary key`
- `name text not null`
- `description text null`
- `color text null` (hex token/string tervalidasi)
- `icon text null` (icon key dari allowlist, bukan arbitrary widget code)
- `sort_order integer not null default 0`
- `is_archived boolean not null default false`
- `created_at timestamptz not null`
- `updated_at timestamptz not null`
- `version bigint not null default 1`
- No `parent_id`: group is simple, not nested.

### `debts`
- `id uuid primary key`
- `customer_id uuid not null references customers(id)`
- `group_id uuid null references debt_groups(id) on delete set null`
- `title text not null`
- `principal_amount bigint not null check (principal_amount > 0)`
- `due_date date null`
- `notes text null`
- `is_archived boolean not null default false`
- `created_at timestamptz not null`
- `updated_at timestamptz not null`
- `version bigint not null default 1`

Paid amount is calculated from payments. Debt status should be derived in query/domain, not blindly stored as a mutable status.

### `payments`
- `id uuid primary key`
- `debt_id uuid not null references debts(id)`
- `amount bigint not null check (amount > 0)`
- `paid_at timestamptz not null`
- `notes text null`
- `operation_id uuid not null unique`
- `created_at timestamptz not null`

Payments are append-only. Enforce no duplicate `operation_id`. Any correction must be represented by an auditable adjustment/reversal design.

### `admin_settings`
- Single logical row, e.g. fixed UUID.
- `pin_hash text not null`
- `pin_hash_algorithm text not null`
- `updated_at timestamptz not null`
- Optional `pin_changed_at`, failed attempt metadata handled safely.

### `audit_logs`
- `id uuid primary key`
- `actor_type text`
- `action text`
- `entity_type text`
- `entity_id uuid null`
- `operation_id uuid null`
- `metadata jsonb` (allowlisted, no secrets)
- `created_at timestamptz`

### `admin_sessions`
- `id uuid primary key`
- `token_hash text not null unique` (SHA-256 hex; token asli tidak disimpan)
- `device_id text not null`
- `issued_at timestamptz not null`
- `expires_at timestamptz not null`
- `revoked_at timestamptz null`
- `last_used_at timestamptz null`
- `created_at timestamptz not null`

### `operation_registry`
- `operation_id uuid primary key`
- `actor_type text not null`
- `operation text not null`
- `entity_type text not null`
- `entity_id uuid null`
- `payload_hash text not null` (SHA-256 hex; payload asli tidak disimpan)
- `status text not null` (`processing`, `succeeded`, `failed`)
- `response jsonb null`
- `error_code text null`
- `created_at`, `updated_at`, `completed_at timestamptz`

### `read_devices`
- `id uuid primary key`
- `name text not null` (label perangkat)
- `device_id text not null` (identifier perangkat)
- `token_hash text not null unique` (SHA-256 hex; token asli tidak disimpan)
- `created_by_session_id uuid null` (sesi admin yang melakukan enrollment)
- `created_at timestamptz not null`
- `last_seen_at timestamptz null`
- `expires_at timestamptz not null`
- `revoked_at timestamptz null`
- Hanya satu enrollment aktif per `device_id`; perangkat yang dicabut dapat
  di-enroll ulang.

## 2. Local schema — implemented in Sprint 02

Drift schema version 1 mirrors the business entities:

- `customers`, `debt_groups`, `debts`, and `payments` with the same business
  fields as cloud.
- Mutable entities carry `version`, `sync_state` (`pending`, `synced`,
  `conflict`), and `server_updated_at`.
- `payments.operation_id` is unique and payments are append-only. SQLite
  triggers also reject direct UPDATE/DELETE.
- `sync_queue` stores `operation_id`, entity type/ID, operation, JSON payload,
  created time, retry count, status, last error code, and next retry time.
- `sync_metadata` stores pull cursors by key.
- `PRAGMA foreign_keys = ON`; customer/debt references restrict deletion and
  group deletion sets `debts.group_id` to null.
- Database is opened by `drift_flutter`; bootstrap opens it before the app shell.
- Schema version 1 has no previous migration. `onUpgrade` intentionally throws
  until explicit migration steps are added; every future schema change must
  include a migration test.
- Local writes use Drift companions so nullable fields can be explicitly
  cleared. Data-class-only upserts omit nulls and are not used for updates.
- Demo seed is development-only, opt-in via `SEED_DEMO_DATA=true`, marked
  `synced`, and does not create outbox entries.
- Local SQLite encryption/app lock is still an owner decision.

## 3. Security model

### Public read
- Anonymous read is only allowed if product owner explicitly accepts that shared debt data is public to anyone who knows the project API.
- Expose only fields that public users need; consider a safe view/RPC instead of direct table reads.
- Never expose PIN hash, audit details, private notes, or unnecessary customer contact data to anon.
- RLS enabled on every exposed table.
- No anon INSERT/UPDATE/DELETE policies.

**Implemented decision (12 November 2026):** owner chose **Option A — no public
read**. There are no anon/authenticated policies, no public views/RPCs, and the
anon/authenticated roles have no `USAGE` on schema `public`. All cloud reads and
writes go through Edge Functions using the service role after session
verification. Adding public read later requires a new owner decision and a new
migration.

### Read-only device access (Option A+)

Owner approved admin-enrolled read-only devices on 12 November 2026. This is not
anonymous public read:

- Admin enrolls a device from an authenticated admin session.
- The device receives an opaque token once; the server stores only its SHA-256
  hash in `read_devices`.
- Every pull verifies `token_hash`, `expires_at`, `revoked_at`, and updates
  `last_seen_at`.
- The token grants pull-only access. It cannot mutate data.
- Admin can revoke a device at any time.
- anon/authenticated still have no schema or table access.

Fields visible to an enrolled read-only device, per owner decision:

- customer name, phone, and notes;
- debt title, principal, paid/outstanding totals, status, due date, and notes;
- group name, description, color, and icon;
- payment history including amount, paid date, and notes.

Not visible: `admin_settings`, `admin_sessions`, `audit_logs`,
`operation_registry`, PIN/token material, and other server-only metadata.
Retention of phone/notes is an explicit owner privacy tradeoff; do not expose
these fields through any anon path.

### Admin mutation
- Admin mutations go through Edge Functions.
- Verify admin session/token server-side on every mutation.
- Service role secret is only in Edge Function environment.
- Validate payload, IDs, amount, dates, ownership/relations, version, and idempotency.
- Rate-limit PIN verification; use constant-time comparison where applicable.
- Do not return PIN hash.
- Admin token should be signed, short-lived, revocable/rotatable, and bound to intended app/device as feasible.
- Never treat a client-side boolean `isAdmin=true` as authorization.

### PIN
- PIN is low entropy. Hashing alone does not make a short PIN strong.
- Use server-side secret/pepper and a suitable password hashing strategy supported by the deployment; evaluate rate limiting and lockout.
- PIN verification response must not leak whether partial data is correct.
- Offline admin unlock is local convenience only; it is not cloud authorization.
- On reconnect, server must require a valid admin session for mutation.

### Data privacy decision required
No-login + shared data implies access-control tradeoffs. Before release, owner must decide:
1. Is the debt list truly public to every app user?
2. Which customer fields can public users see?
3. Should public access be read-only and limited to a public-safe view?
4. Is device-level app lock required?

**Status 12 November 2026:** questions 1–3 resolved by Option A + read-only
device enrollment: the debt list is not public, no anon fields are exposed, and
only admin-enrolled devices may pull read-only data. Device-level app lock is
still pending owner confirmation.

### Implemented database guards

- All business tables have RLS enabled; Edge Functions use `service_role` after
  admin session or read-only device token verification.
- `read_devices` has RLS enabled, no anon/authenticated policies, and only
  service-role grants.
- `payments` and `audit_logs` reject UPDATE/DELETE through database triggers.
- `payments.operation_id` and `operation_registry.operation_id` are unique.
- `version` and `updated_at` are bumped by trigger on mutable tables.
- `debts.group_id` is `ON DELETE SET NULL` (Unassigned); customer/debt
  references with history use `ON DELETE RESTRICT`.
- `debt_groups` has no `parent_id`; group icons use an allowlist.
- Local group deletion is transactional: all debts are explicitly moved to
  Unassigned with version bumps and outbox updates, then the group delete is
  queued. Debts and payments are never deleted.
- Customer hard-delete is not exposed; customer archive/restore preserves all
  debt history.
- Group/customer summaries are derived from active debts and payments, not
  stored counters.

## 4. RLS checklist
- Enable RLS on all exposed tables.
- Explicit policies only.
- Anon SELECT only on approved public view/RPC or approved tables.
- No anon mutation.
- No direct anon access to `admin_settings` or `audit_logs`.
- No direct anon access to `read_devices`; only server-side token checks.
- Read-only device tokens grant pull only, never mutation.
- Test policies with anon role and authenticated role.
- Verify service role is not shipped in Flutter.
