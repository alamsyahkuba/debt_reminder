# Project Status

## Current phase

Plan revised on 12 November 2026: two roles (owner/admin and public), no
customer entity, groups retained, all business data public, admin PIN retained,
device enrollment removed, and database reset approved. Cloud rework (Sprint
01R), local rework (Sprint 02R/03R), Sprint 04 debt management, Sprint 05
payments/dashboard, Sprint 06 admin PIN/session, and Sprint 07 offline sync are
complete. Ready for Sprint 08.

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
- [x] Sprint 07 — Offline sync (public pull, outbox sync, idempotency,
      retry/backoff, conflict resolution, sync status, background best-effort)
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

- Drift schema v3 (v2 in Sprint 02, conflict data added in Sprint 07) has
  `debt_groups`, `debts`, `payments`, `sync_queue`, and `sync_metadata`; no
  customers and no `customer_id`.
- Destructive v1→v3 migration resets old data; migration test passes.
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

### Sprint 07 — Offline sync (complete)

- Public pull uses paginated RPCs with keyset cursors for groups, debts, and
  payments. Payments are inserted append-only; local unsynced edits and local
  outbox rows are never overwritten by public pull.
- Public pull runs on app start, on connectivity return, on app resume, on
  manual sync, and best-effort through WorkManager. Cached data remains readable
  when pull fails.
- Admin sync claims queued operations one at a time with dependency ordering:
  group create/update, debt, payment, then group delete.
- Every outbox operation keeps its stable `operation_id`; the server registry
  returns the prior response on replay. Payments additionally have a unique
  server `operation_id`.
- Server mutation is atomic in `admin_apply_mutation`: idempotency, version
  check, business validation, audit, and response.
- Transient network/5xx failures retry with exponential backoff + jitter.
  Authentication failures preserve the queue and stop automatic sending until
  admin re-authenticates.
- Stale versions return a conflict with server version and snapshot. Settings UI
  offers “Muat ulang server” or “Pertahankan lokal”, then resumes sync.
- Drift schema v3 adds `sync_queue.conflict_data`; payment sync metadata updates
  are allowed without allowing financial field edits.
- Sync status is visible on the dashboard and Settings, with pending/conflict/
  failed counts, last successful timestamps, error state, and manual sync.

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
- [x] Reset SQLite schema/data with destructive v1→v2 (now v3) migration.
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
  implementation status through Sprint 07.
- `README.md` — product status, local DB target, public read policy, payments,
  dashboard, admin session, and offline sync.
- `supabase/README.md` — public RPC pagination, admin PIN/sync Edge Functions,
  token header, and deployment secrets.

## Test evidence

Backend Sprint 07:
```text
supabase db reset                                                                                    passed
supabase test db                                                                                     passed, 163 pgTAP assertions
  - admin_mutation.test.sql                                                                          28
  - admin_security.test.sql                                                                          33
  - public_read.test.sql                                                                             26
  - schema_security.test.sql                                                                         53
  - idempotency.test.sql                                                                             23
supabase db lint                                                                                     passed
deno fmt --check / deno check / deno lint / deno test                                                passed, 64 tests
admin-sync integration                                                                               passed
  - group/debt/payment create                                                                        200 / 200 / 200
  - payment replay                                                                                   200, one payment row
  - stale debt update                                                                                409 version_conflict
  - public page RPC                                                                                  200, one group
  - audit registry                                                                                    rows appended
```

Flutter (Sprint 07):
```text
dart format --output=none --set-exit-if-changed .                                                passed
flutter analyze                                                                                  no issues
flutter test                                                                                     passed, 68 tests
flutter build apk --debug                                                                        passed
  - public pull pagination/no-outbox tests                                                        passed
  - pending local row preservation                                                                 passed
  - group → debt → payment ordering                                                                passed
  - restart/processing recovery                                                                   passed
  - auth/network retry behavior                                                                   passed
  - version conflict reload/keep-local                                                            passed
  - public/admin HTTP client parsing                                                              passed
  - sync settings/conflict UI                                                                     passed
  - settings test cleanup with bounded settle                                                      passed
```

## Blockers / known limitations

- Cloud and local schemas are reworked; no customers/read_devices/customer_id.
- No Android device was connected during Sprint 04/05/06/07 verification.
- Cloud Supabase, `admin-pin`, and `admin-sync` Edge Functions have not been
  linked, deployed, or configured with production secrets.
- WorkManager/background sync compiles but has not been verified on a physical
  Android device; foreground/manual sync remains the reliable path.
- The `sync_settings_test.dart` widget test requires explicit empty Supabase
  config and must unmount its ProviderScope before closing Drift; teardown is
  bounded and verified.
- Public pull does not expose server `version`. Rows pulled from another device
  keep a local version guess and may surface a conflict on first admin edit;
  the conflict UI resolves it.
- Group deletion reconciliation is only done on a full manual pull. Incremental
  pulls do not delete local groups that disappeared server-side.
- Background WorkManager may open SQLite while the foreground app is active.
  SQLite handles concurrent connections, but this needs device verification.
- Local management controls are read-only when locked, but local UI guards are
  not a substitute for server authorization.
- Offline local-only unlock is currently disabled pending owner confirmation. A
  valid server session is required before offline edits can be queued; if it
  expires, local work already in the outbox is preserved.
- Local SQLite is not encrypted; device-level app lock/encryption remains an
  owner decision.
- Public read is intentionally world-readable to anyone with the anon key.
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
- Public pull uses keyset pagination and never writes outbox. Admin sync is
  dependency-ordered, idempotent, retries transient errors, and surfaces version
  conflicts with reload/keep-local resolution.
- See `plans/DECISIONS.md`, especially D-013 through D-019.

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

Request owner approval to start Sprint 08 (Reminders). Public pull, admin sync,
conflict resolution, and sync status are implemented; device-level WorkManager
verification remains outstanding.
