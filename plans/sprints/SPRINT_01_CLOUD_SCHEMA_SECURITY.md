# Sprint 01 — Cloud Schema & Security

## Goal
Build Supabase schema, migrations, RLS, and secure server foundation.

## Tasks
- [x] Initialize Supabase CLI/config.
- [x] Create migrations for customers, debt_groups, debts, payments, admin_settings, audit_logs, operation registry.
- [x] Add constraints, indexes, timestamps, version fields.
- [x] Add safe views/RPC for approved public read fields.
- [x] Enable RLS on all exposed tables.
- [x] Create explicit anon read policies only for approved public data.
- [x] Ensure anon has no mutation access.
- [x] Ensure admin_settings/audit_logs are inaccessible to anon.
- [x] Define Edge Function shared auth/validation helpers.
- [x] Add server-side idempotency handling.
- [x] Add SQL tests/RLS tests where tooling permits.
- [x] Document local Supabase setup and migration commands.

> Catatan: owner memilih Option A (tidak ada public read), sehingga tidak ada
> public view/RPC atau policy anon yang dibuat. Task view/RPC ditutup dengan
> keputusan eksplisit tersebut, bukan dengan mengekspos data.

## Deliverables
- Reproducible migrations.
- Security policy tests.
- Schema documentation.

## Acceptance criteria
- Fresh local Supabase can apply all migrations.
- RLS is enabled on exposed tables.
- Anon mutation is denied.
- Sensitive fields are not available through public read endpoint.
- No service role key appears in Flutter files.

## Owner decision gate

**Resolved 12 November 2026:** owner chose Option A — no public read. No public
view/RPC or anon policy is allowed in v1. Owner then approved read-only device
enrollment (Option A+): admin-enrolled devices may pull approved fields,
including phone and notes, using a revocable device token. Anon remains denied.

## Post-sprint extension — read-only device enrollment

- [x] Add `read_devices` table with token hash, expiry, revocation, and active
      device uniqueness.
- [x] Enable RLS and deny anon/authenticated access.
- [x] Add device-token generation/hash/verification helpers.
- [x] Add pgTAP tests for enrollment constraints and anon denial.
- [x] Add Deno tests for device token verification.
- [ ] Enrollment/revocation endpoint and UI (Sprint 06).
- [ ] Read-only pull endpoint and field allowlist (Sprint 07).

## Verification (12 November 2026)

| Check | Result |
|---|---|
| `supabase db start` | Passed; local PostgreSQL started and migrations applied |
| `supabase db reset` | Passed; fresh database recreated from all migrations |
| `supabase test db` | Passed; 92 pgTAP assertions across schema/RLS/idempotency/read-devices |
| `supabase db lint` | Passed; no schema errors |
| `deno fmt --check` | Passed |
| `deno check _shared/*.ts` | Passed |
| `deno lint` | Passed |
| `deno test` | Passed; 43 helper tests |
| Anon/authenticated access | Denied at schema, table, and function level |
| Sensitive tables | `admin_settings` and `audit_logs` inaccessible to anon |
| Read-only devices | `read_devices` RLS enabled; anon denied; token/revocation/expiry tests passed |
| Service-role key in Flutter | Not present; scan verified |
| Cloud `db push` | Not run; no linked project or owner-provided cloud credentials |
| CI workflow | Added for database/Deno tests; not executed from this local environment |
