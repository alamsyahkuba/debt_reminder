# Sprint 01 — Cloud Schema & Security

> **Sprint 01R complete (12 November 2026):** customer entity and read-only
> device enrollment were removed. Public read-only RPCs and revised RLS/tests
> are implemented.

## Goal
Build the revised Supabase schema, public read-only RPCs, RLS, and secure admin
server foundation.

## Tasks
- [x] Reset Supabase migrations to the revised schema.
- [x] Remove `customers`, `debts.customer_id`, and `read_devices`.
- [x] Create migrations for `debt_groups`, `debts`, `payments`,
      `admin_settings`, `audit_logs`, `admin_sessions`, and
      `operation_registry`.
- [x] Add constraints, indexes, timestamps, version fields, allowlisted icons,
      and integer rupiah limits.
- [x] Add public read-only RPCs for groups, debts, and payments.
- [x] Ensure public RPCs expose all business fields but not `version`,
      `operation_id`, sync metadata, admin/audit/session data.
- [x] Enable RLS on all base tables.
- [x] Grant anon execute only on public read RPCs; no anon table SELECT.
- [x] Ensure anon has no INSERT/UPDATE/DELETE.
- [x] Ensure `admin_settings`, `admin_sessions`, `audit_logs`, and
      `operation_registry` are inaccessible to anon.
- [x] Define Edge Function shared auth/validation helpers for admin mutation.
- [x] Add server-side idempotency handling.
- [x] Add SQL/RLS tests for public read and anon mutation denial.
- [x] Document local Supabase setup, reset, and migration commands.

## Deliverables
- Reproducible revised migrations.
- Public read-only RPCs.
- RLS/security tests.
- Schema documentation.

## Acceptance criteria
- [x] Fresh local Supabase applies all revised migrations.
- [x] `customers`, `read_devices`, and `customer_id` do not exist.
- [x] Anon can read group/debt/payment data via public RPC.
- [x] Anon cannot read base tables directly.
- [x] Anon cannot mutate any table or RPC.
- [x] Sensitive/internal tables are inaccessible to anon.
- [x] No service role key appears in Flutter files.
- [x] Public RPC does not expose internal metadata.

## Owner decision gate
Resolved 12 November 2026: all business fields are public. Public access is
read-only through RPC. Customer data and device enrollment are removed.

## Verification (12 November 2026)

| Check | Result |
|---|---|
| `supabase db reset` | Passed; revised baseline applied |
| `supabase test db` | Passed; 92 pgTAP assertions |
| `schema_security.test.sql` | Passed; 53 assertions |
| `public_read.test.sql` | Passed; 16 assertions |
| `idempotency.test.sql` | Passed; 23 assertions |
| `supabase db lint` | Passed; no schema errors |
| `deno fmt --check` / `deno check` / `deno lint` / `deno test` | Passed; 36 tests |
| Customers/read_devices/customer_id | Verified absent |
| Anon public read | Verified through public RPCs |
| Anon base-table/mutation access | Verified denied |
| Internal tables | Verified inaccessible to anon |
| Cloud `db push` | Not run; no linked cloud project yet |
