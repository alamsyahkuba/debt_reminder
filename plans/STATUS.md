# Project Status

## Current phase

Plan revised on 12 November 2026: two roles (owner/admin and public), no
customer entity, groups retained, all business data public, admin PIN retained,
device enrollment removed, and database reset approved. Cloud rework (Sprint
01R), local rework (Sprint 02R/03R), Sprint 04 debt management, Sprint 05
payments/dashboard, and Sprint 06 admin PIN/session are complete. Ready for
Sprint 07.

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
- [x] Sprint 06 — Admin PIN & sessions (server PIN verification, rate limit,
      secure session, route guards, PIN change, audit)
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

### Sprint 06 — Admin PIN & session (complete)

- Drawer → Admin opens a 6-digit PIN screen; PIN verification is server-side
  through the `admin-pin` Edge Function.
- PIN hashing uses PBKDF2-HMAC-SHA256 with a random salt and server pepper.
- Five failed attempts lock verification for 15 minutes.
- Successful login issues a 15-minute JWT, stored in `flutter_secure_storage`;
  the server stores only its SHA-256 hash and binds it to a device id.
- The admin token travels in `x-admin-session`; `Authorization` continues to
  carry the Supabase anon key for gateway verification.
- Admin panel supports session lock/revocation and PIN change. Changing the PIN
  revokes other active sessions.
- Route guards redirect new/edit/payment routes to PIN when locked, then return
  to the requested route after unlock.
- Read screens remain available without a session. Mutation controls are hidden
  or disabled while locked and re-checked in action handlers.
- Session expiry automatically locks the UI and clears secure storage.
- Audit logs record verification, failures, PIN changes, and logout without
  storing PIN or token material.
- Initial bootstrap uses `ADMIN_INITIAL_PIN`; the singleton admin settings row
  starts `uninitialized`, so bootstrap attempts are rate-limited too.

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

- `AGENTS.md` — revised roles/data/public-read/security/rework rules and current
  implementation status through Sprint 06.
- `README.md` — product status, local DB target, public read policy, and
  payment/dashboard/admin session status through Sprint 06.
- `supabase/README.md` — public RPC/RLS model, removal of customers and device
  enrollment, admin PIN Edge Function, token header, and deployment secrets.

## Test evidence

Backend Sprint 06:
```text
supabase db reset                                                                                    passed
supabase test db                                                                                     passed, 125 pgTAP assertions
  - admin_security.test.sql                                                                          33
  - schema_security.test.sql                                                                         53
  - public_read.test.sql                                                                             16
  - idempotency.test.sql                                                                             23
supabase db lint                                                                                     passed
deno fmt --check / deno check / deno lint / deno test                                                passed, 54 tests
admin-pin integration                                                                                passed
  - verify bootstrap                                                                                 token issued
  - change PIN / verify new PIN                                                                      200 / 200
  - missing/revoked admin token                                                                      401 / 401
  - rate limit                                                                                       401,401,401,401,429
  - audit log                                                                                         rows appended
```

Flutter (Sprint 06):
```text
dart format --output=none --set-exit-if-changed .                                                passed
flutter analyze                                                                                  no issues
flutter test                                                                                     passed, 48 tests
flutter build apk --debug                                                                        passed
  - payment/dashboard regression tests                                                           passed
  - PIN success/failure/change/lock flow                                                         passed
  - admin route guard and return-to flow                                                         passed
  - locked mutation-control tests                                                                passed
  - automatic session expiry test                                                                passed
  - HTTP admin client error mapping                                                              passed
```

## Blockers / known limitations

- Cloud and local schemas are reworked; no customers/read_devices/customer_id.
- No Android device was connected during Sprint 04/05/06 verification.
- Cloud Supabase and the `admin-pin` Edge Function have not been linked,
  deployed, or configured with production secrets.
- Admin PIN/session is enforced for existing admin endpoints; Sprint 07 sync
  mutation endpoints must reuse `requireAdminSession` server-side.
- Local management controls are read-only when locked, but local UI guards are
  not a substitute for server authorization.
- Offline unlock is intentionally disabled; a valid server session is required
  before offline edits can be queued. If the session expires while offline,
  local work already in the outbox is preserved.
- Dashboard shows local data and a local-only notice; the outbox-driven sync
  indicator arrives with Sprint 07.
- Local SQLite is not encrypted; device-level app lock/encryption remains an
  owner decision.
- Public read is intentionally world-readable to anyone with the anon key.
- Existing outbox is not synced yet; sync is Sprint 07.
- Public Flutter read-only mode/pull is not implemented; Sprint 07.
- Initial PIN bootstrap depends on `ADMIN_INITIAL_PIN`; remove it after setup.

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
- Admin PIN is 6 digits, 5 failed attempts lock verification for 15 minutes, and
  sessions last 15 minutes. Admin token uses `x-admin-session`.
- See `plans/DECISIONS.md`, especially D-013, D-014, D-015, D-016, D-017, and
  D-018.

## Owner decisions still pending

- [x] Confirm PIN policy: 6 digits, 5 failed attempts, 15-minute lockout and
      session; selected by owner for Sprint 06.
- [x] Overpayment policy: default reject implemented in Sprint 05; owner may
      revise before release.
- [ ] Confirm archive/delete policy for debts (group delete already defined).
- [ ] Confirm exact reminder schedule and whether exact alarms are required.
- [ ] Confirm whether device-level app lock/local SQLite encryption is required.
- [ ] Confirm whether offline local-only unlock is required; currently admin PIN
      verification requires the server.

Resolved 12 November 2026: public read all business data, no customers, groups
retained, admin PIN retained, device enrollment removed, database reset.

## Next step

Request owner approval to start Sprint 07 (Offline sync). Public Flutter
read-only mode/pull and mutation endpoints remain part of Sprint 07.
