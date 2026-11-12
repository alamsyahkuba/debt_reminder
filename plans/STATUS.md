# Project Status

## Current phase

Plan revised on 12 November 2026: two roles (owner/admin and public), no
customer entity, groups retained, all business data public, admin PIN retained,
device enrollment removed, and database reset approved. Cloud rework (Sprint
01R), local rework (Sprint 02R/03R), Sprint 04 debt management, and Sprint 05
payments/dashboard are complete. Ready for Sprint 06.

## Sprint status

- [x] Sprint 00 — Foundation (historical; customer placeholder removed by the
      public-read rework)
- [x] Sprint 01 — Cloud schema & security (Sprint 01R: customers/read_devices
      removed, public read RPC and tests added)
- [x] Sprint 02 — Local database & repository (Sprint 02R: Drift v2 reset,
      customers removed, 32 Flutter tests pass; public pull deferred to Sprint 07)
- [x] Sprint 03 — Groups (Sprint 03R: group UI retained, customer UI/tests
      removed; public read-only UI deferred to Sprint 07)
- [x] Sprint 04 — Debt management (debt form/list/detail/search/filter/sort,
      derived status, archive)
- [x] Sprint 05 — Payments & dashboard (payment form, overpayment rejection,
      append-only history, derived dashboard totals/status/group/upcoming)
- [ ] Sprint 06 — Admin PIN & sessions
- [ ] Sprint 07 — Offline sync
- [ ] Sprint 08 — Reminders
- [ ] Sprint 09 — QA, hardening & release

## Implementation status by area

### Sprint 00 — Foundation

- Flutter foundation, Material 3, Indonesian locale, Riverpod, GoRouter,
  drawer, environment config, lint, CI, and placeholder screens.
- Debug APK was verified on I2505 during Sprint 00.
- Customer placeholder was removed in Sprint 03R.

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

### Sprint 02 — Local database & repository (Sprint 02R complete)

- Drift schema v2 has `debt_groups`, `debts`, `payments`, `sync_queue`, and
  `sync_metadata`; no customers and no `customer_id`.
- Destructive v1→v2 migration resets old data; migration test passes.
- Customer entity/DAO/repository, customer payloads, and provider were removed.
- Debt repository and payloads no longer contain customer references.
- 32 Flutter tests and APK build pass.

### Sprint 03 — Groups (Sprint 03R complete)

- Group list/form/detail, archive/restore/delete, summaries, and move debt remain.
- Customer UI, providers, routes, navigation item, and tests were removed.
- Group flow and group-management tests pass.
- Public read-only UI/pull behavior remains part of the sync/public-mode work in
  Sprint 07.

### Sprint 04 — Debt management (complete)

- Debt list with search by title/notes, group/status/due filters, and sorting.
- Debt create/edit form without customer selector.
- Debt detail with group, principal, paid, outstanding, due date, notes, and
  payment history.
- Derived `unpaid`/`partial`/`paid`/`overdue` status from payments and due date.
- Archive/restore and move-group actions.
- Group detail debt rows navigate to debt detail.
- Repository/UI tests cover debt creation, search, status, payment history, and
  archive.

### Sprint 05 — Payments & dashboard (complete)

- Payment form from debt detail with amount, payment date, notes, and
  confirmation before saving.
- Payment creation is append-only, writes the entity and outbox entry in one
  SQLite transaction, and keeps a stable `operation_id`.
- Overpayment is rejected in the repository inside the transaction and by form
  validation; amount must be positive.
- Payment history remains visible in debt detail with amount, date, and notes.
- Dashboard derives principal, paid, and outstanding totals plus active,
  partial, overdue, and paid counts from `DebtOverview`.
- Group summary includes active groups, archived groups that still have active
  debts, and Unassigned.
- Upcoming section shows overdue and next-seven-day debts, excludes paid debts.
- Repository and widget tests cover overpayment, payment flow, and dashboard
  aggregation.

## Required revision work

Cloud (done in Sprint 01R):
- [x] Remove `customers`, `debts.customer_id`, `read_devices`, and device auth.
- [x] Add public read-only RPCs for groups, debts, and payments.
- [x] Keep base tables RLS-enabled with no anon table grants.
- [x] Allow anon execute only on public read RPCs.
- [x] Keep internal tables private.
- [x] Reset local Supabase and update backend tests.

Local (Sprint 02R/03R) — done:
- [x] Remove customer table/entity/DAO/repository/validation.
- [x] Remove `customer_id` from local debts.
- [x] Remove customer providers/screens/routes and tests.
- [x] Remove local device-token/device-enrollment artifacts.
- [x] Reset SQLite schema/data with destructive v1→v2 migration.
- [x] Rework debt repository/UI to remove customer selectors and summaries.
- [x] Update widget/repository tests for group/debt/payment.
- [x] Keep group features and remove customer navigation.
- [x] Update root README/AGENTS/status when local rework completed.

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

Backend Sprint 01R (rerun during Sprint 05):
```text
supabase db reset                                                                                    passed
supabase test db                                                                                     passed, 92 pgTAP assertions
  - schema_security.test.sql                                                                         53
  - public_read.test.sql                                                                             16
  - idempotency.test.sql                                                                             23
supabase db lint                                                                                     passed
deno fmt --check / deno check / deno lint / deno test                                                passed, 36 tests (Sprint 01R; not rerun)
```

Flutter (Sprint 05):
```text
dart format --output=none --set-exit-if-changed .                                                passed
flutter analyze                                                                                  no issues
flutter test                                                                                     passed, 40 tests
flutter build apk --debug                                                                        passed
  - schema v2 + no customers                                                                      passed
  - destructive v1→v2 migration                                                                  passed
  - group/debt/payment repository tests                                                           passed
  - overpayment and payment flow tests                                                           passed
  - debt overview/status tests                                                                   passed
  - dashboard aggregation/group/upcoming tests                                                   passed
  - group and debt flow widget tests                                                             passed
```

## Blockers / known limitations

- Cloud and local schemas are reworked; no customers/read_devices/customer_id.
- No Android device was connected during Sprint 04/05 verification.
- Cloud Supabase has not been linked or pushed.
- Admin PIN UI gating is not implemented yet; local management actions are
  currently accessible until Sprint 06.
- Dashboard shows local data and a local-only notice; the outbox-driven sync
  indicator arrives with Sprint 07.
- Local SQLite is not encrypted; device-level app lock/encryption remains an
  owner decision.
- Public read is intentionally world-readable to anyone with the anon key.
- Existing outbox is not synced yet; sync is Sprint 07.
- Public Flutter read-only mode/pull is not implemented; Sprint 07.

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
- Debt paid/outstanding/status is derived from payments and due date.
- Payments are append-only; overpayment is rejected by default in repository
  and form validation.
- Dashboard totals, counts, group summaries, and upcoming debts are derived from
  the same debt overviews as the debt list.
- See `plans/DECISIONS.md`, especially D-013, D-014, D-015, D-016, and D-017.

## Owner decisions still pending

- [ ] Confirm PIN length and recovery/rotation process.
- [x] Overpayment policy: default reject implemented in Sprint 05; owner may
      revise before release.
- [ ] Confirm archive/delete policy for debts (group delete already defined).
- [ ] Confirm exact reminder schedule and whether exact alarms are required.
- [ ] Confirm whether device-level app lock/local SQLite encryption is required.

Resolved 12 November 2026: public read all business data, no customers, groups
retained, admin PIN retained, device enrollment removed, database reset.

## Next step

Request owner approval to start Sprint 06 (Admin PIN & sessions). Public
read-only UI and pull behavior remain scheduled for Sprint 07.
