# Sprint 01 — Cloud Schema & Security

## Goal
Build Supabase schema, migrations, RLS, and secure server foundation.

## Tasks
- [ ] Initialize Supabase CLI/config.
- [ ] Create migrations for customers, debt_groups, debts, payments, admin_settings, audit_logs, operation registry.
- [ ] Add constraints, indexes, timestamps, version fields.
- [ ] Add safe views/RPC for approved public read fields.
- [ ] Enable RLS on all exposed tables.
- [ ] Create explicit anon read policies only for approved public data.
- [ ] Ensure anon has no mutation access.
- [ ] Ensure admin_settings/audit_logs are inaccessible to anon.
- [ ] Define Edge Function shared auth/validation helpers.
- [ ] Add server-side idempotency handling.
- [ ] Add SQL tests/RLS tests where tooling permits.
- [ ] Document local Supabase setup and migration commands.

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
Do not finalize public read policies until owner confirms visibility of debt/customer fields.
