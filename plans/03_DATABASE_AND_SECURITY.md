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

## 2. Local schema

Mirror the business entities in Drift. Include:
- local sync state (`pending`, `synced`, `conflict`, etc.)
- server version/updated timestamp
- tombstone/archive fields as needed
- `sync_queue` with operation ID, entity type, entity ID, operation, payload, created time, retry count, status, last error code
- `sync_cursor`/metadata for pull synchronization

Use migrations and schema versioning. Test migrations from previous versions.

## 3. Security model

### Public read
- Anonymous read is only allowed if product owner explicitly accepts that shared debt data is public to anyone who knows the project API.
- Expose only fields that public users need; consider a safe view/RPC instead of direct table reads.
- Never expose PIN hash, audit details, private notes, or unnecessary customer contact data to anon.
- RLS enabled on every exposed table.
- No anon INSERT/UPDATE/DELETE policies.

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

## 4. RLS checklist
- Enable RLS on all exposed tables.
- Explicit policies only.
- Anon SELECT only on approved public view/RPC or approved tables.
- No anon mutation.
- No direct anon access to `admin_settings` or `audit_logs`.
- Test policies with anon role and authenticated role.
- Verify service role is not shipped in Flutter.
