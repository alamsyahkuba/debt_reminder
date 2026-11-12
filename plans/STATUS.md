# Project Status

## Current phase

Plan revised on 12 November 2026: two roles (owner/admin and public), no
customer entity, groups retained, all business data public, admin PIN retained,
device enrollment removed, and database reset approved. Sprint 01R cloud rework
is complete; local Flutter/Drift rework (Sprint 02R/03R) is still pending.

## Sprint status

- [x] Sprint 00 — Foundation (historical; customer placeholder will be removed
      by the public-read rework)
- [x] Sprint 01 — Cloud schema & security (Sprint 01R: customers/read_devices
      removed, public read RPC and tests added)
- [ ] Sprint 02 — Local database & repository (revision required: remove
      customer schema/repositories, reset Drift schema)
- [ ] Sprint 03 — Groups (revision required: remove customer UI/tests, retain
      group features)
- [ ] Sprint 04 — Debt management
- [ ] Sprint 05 — Payments & dashboard
- [ ] Sprint 06 — Admin PIN & sessions
- [ ] Sprint 07 — Offline sync
- [ ] Sprint 08 — Reminders
- [ ] Sprint 09 — QA, hardening & release

## Implementation status by area

### Sprint 00 — Foundation

- Flutter foundation, Material 3, Indonesian locale, Riverpod, GoRouter,
  drawer, environment config, lint, CI, and placeholder screens.
- Debug APK was verified on I2505 during Sprint 00.
- Customer placeholder still exists in Flutter and must be removed in Sprint 03R.

### Sprint 01 — Cloud schema & security (Sprint 01R complete)

- Supabase baseline migrations now contain `debt_groups`, `debts`, `payments`,
  admin settings, audit logs, admin sessions, and operation registry only.
- `customers`, `debts.customer_id`, `read_devices`, and device auth were removed.
- Public read-only RPCs: `public_debt_groups`, `public_debts`,
  `public_payments`.
- RLS is enabled; anon has schema usage and execute on public RPCs only; anon
  has no base-table grants or mutation.
- Public RPC tests, anon denial tests, idempotency tests, and Deno admin helper
  tests pass after reset.
- Device auth helper/tests were deleted; http error mapping no longer references
  device errors.

### Sprint 02 — Local database & repository (pending rework)

- Drift schema v1 still contains customers and customer_id.
- Customer repository/entity/DAO and device-token helpers remain in Flutter.
- Must be reset/reworked in Sprint 02R.

### Sprint 03 — Groups & customers (pending rework)

- Group list/form/detail, archive/restore/delete, summaries, move debt.
- Customer list/form/detail/search/archive still exists.
- Customer module must be removed in Sprint 03R; group features remain.

## Required revision work

Cloud (done in Sprint 01R):
- [x] Remove `customers`, `debts.customer_id`, `read_devices`, and device auth.
- [x] Add public read-only RPCs for groups, debts, and payments.
- [x] Keep base tables RLS-enabled with no anon table grants.
- [x] Allow anon execute only on public read RPCs.
- [x] Keep internal tables private.
- [x] Reset local Supabase and update backend tests.

Local (Sprint 02R/03R):
- [ ] Remove customer table/entity/DAO/repository/validation.
- [ ] Remove `customer_id` from local debts.
- [ ] Remove customer providers/screens/routes and tests.
- [ ] Remove local device-token/device-enrollment artifacts.
- [ ] Reset SQLite data/schema.
- [ ] Rework debt repository/UI to remove customer selectors and summaries.
- [ ] Update widget/repository tests for group/debt/payment/public mode.
- [ ] Keep group features and remove customer navigation.
- [ ] Update root README/status when local rework is complete.

## Plan files changed

- `plans/00_PROJECT_BRIEF.md`
- `plans/01_PRODUCT_REQUIREMENTS.md`
- `plans/02_ARCHITECTURE.md`
- `plans/03_DATABASE_AND_SECURITY.md`
- `plans/04_OFFLINE_SYNC.md`
- `plans/05_UI_UX_SPEC.md`
- `plans/06_TESTING_AND_ACCEPTANCE.md`
- `plans/07_AGENT_WORKFLOW.md`
- `plans/README.md`
- `plans/DECISIONS.md`
- `plans/STATUS.md`
- `plans/sprints/SPRINT_00_FOUNDATION.md`
- `plans/sprints/SPRINT_01_CLOUD_SCHEMA_SECURITY.md`
- `plans/sprints/SPRINT_02_LOCAL_DATABASE_REPOSITORY.md`
- `plans/sprints/SPRINT_03_GROUPS_CUSTOMERS.md`
- `plans/sprints/SPRINT_04_DEBT_MANAGEMENT.md`
- `plans/sprints/SPRINT_05_PAYMENTS_DASHBOARD.md`
- `plans/sprints/SPRINT_06_ADMIN_SECURITY.md`
- `plans/sprints/SPRINT_07_OFFLINE_SYNC.md`
- `plans/sprints/SPRINT_08_REMINDERS.md`
- `plans/sprints/SPRINT_09_QA_RELEASE.md`

## Documentation outside plans updated

- `AGENTS.md` — revised roles/data/public-read/security/rework rules.
- `README.md` — revised product status, local DB target, public read policy,
  and pending rework.
- `supabase/README.md` — target public RPC/RLS model, removal of customers and
  device enrollment, and reset requirements.

## Test evidence

Backend Sprint 01R (current):
```text
supabase db reset                                                                                    passed
supabase test db                                                                                     passed, 92 pgTAP assertions
  - schema_security.test.sql                                                                         53
  - public_read.test.sql                                                                             16
  - idempotency.test.sql                                                                             23
supabase db lint                                                                                     passed
deno fmt --check / deno check / deno lint / deno test                                                passed, 36 tests
```

Flutter (still old customer/local model):
```text
flutter test                                                                                         passed, 34 tests (historical)
flutter build apk --debug                                                                            passed (historical)
```

Flutter tests will be updated in Sprint 02R/03R after customer removal.

## Blockers / known limitations

- Cloud schema is reworked, but local Flutter/Drift schema still has customers
  and device-token artifacts.
- No Android device was connected during Sprint 02/03 verification.
- Cloud Supabase has not been linked or pushed.
- Admin PIN UI gating is not implemented yet; local management actions are
  currently accessible until Sprint 06.
- Local SQLite is not encrypted; device-level app lock/encryption remains an
  owner decision.
- Public read is intentionally world-readable to anyone with the anon key.
- Existing outbox is not synced yet; sync is Sprint 07.

## Decisions

- Two roles: owner/admin and public.
- One admin; public does not log in.
- Data: groups, debts, payments only; no customers.
- All business fields are public through read-only RPC.
- Anon cannot mutate; admin mutations require server-side session.
- Device enrollment is removed.
- Group deletion moves debts to Unassigned and never deletes history.
- Local-first with Drift and atomic outbox for admin mutations.
- Database reset is approved because the app is pre-release.
- See `plans/DECISIONS.md`, especially D-013, D-014, and D-015.

## Owner decisions still pending

- [ ] Confirm PIN length and recovery/rotation process.
- [ ] Confirm overpayment policy (default reject).
- [ ] Confirm archive/delete policy for debts (group delete already defined).
- [ ] Confirm exact reminder schedule and whether exact alarms are required.
- [ ] Confirm whether device-level app lock/local SQLite encryption is required.

Resolved 12 November 2026: public read all business data, no customers, groups
retained, admin PIN retained, device enrollment removed, database reset.

## Next step

1. Sprint 02R — reset local Drift schema, remove customer table/entity/DAO/
   repository, and remove customer references from debt payloads/tests.
2. Sprint 03R — remove customer UI/providers/routes/tests and keep group UI.
3. After local rework passes tests, continue to Sprint 04.
