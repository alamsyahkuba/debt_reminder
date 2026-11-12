# Project Status

## Current phase

Sprint 00 — Foundation, Sprint 01 — Cloud schema & security (including the
read-only device enrollment foundation), and Sprint 02 — Local database &
repository are complete. Ready for owner approval before Sprint 03.

## Sprint status

- [x] Sprint 00 — Foundation
- [x] Sprint 01 — Cloud schema & security
- [x] Sprint 02 — Local database & repository
- [ ] Sprint 03 — Groups & customers
- [ ] Sprint 04 — Debt management
- [ ] Sprint 05 — Payments & dashboard
- [ ] Sprint 06 — Admin PIN & sessions
- [ ] Sprint 07 — Offline sync
- [ ] Sprint 08 — Reminders
- [ ] Sprint 09 — QA, hardening & release

## Completed work

### Sprint 00 — Foundation (12 November 2026)

- Flutter foundation with Material 3 light/dark theme and Indonesian locale.
- Riverpod `ProviderScope`, app config provider, and typed core foundations.
- GoRouter shell with drawer navigation and seven placeholder screens:
  Dashboard, Semua Hutang, Group Hutang, Pelanggan, Reminder, Pengaturan, and
  Admin PIN.
- Environment configuration through `--dart-define`; example config committed,
  local config ignored.
- Strict lint/analyzer rules, formatter check, and GitHub Actions CI.
- README with setup, configuration, and quality commands.
- Technical decisions recorded in `plans/DECISIONS.md`.
- Sprint 00 itself added no database, CRUD, authentication, or sync code.
- Debug APK installed and launched on I2505 (Android 16, API 36); Dashboard
  rendered and drawer navigation to Group Hutang verified.

### Sprint 01 — Cloud schema & security (12 November 2026)

- Supabase CLI config initialized; local seed disabled and
  `api.auto_expose_new_tables = false`.
- Migrations created for `customers`, `debt_groups`, `debts`, `payments`,
  `admin_settings`, `audit_logs`, `admin_sessions`, and `operation_registry`.
- Added constraints, indexes, timestamps, version triggers, allowlisted group
  icons, safe-integer rupiah limits, and archive/sync indexes.
- Payments and audit logs are append-only at the database trigger level.
- RLS enabled on every table. Option A applied: no public read, no
  anon/authenticated policies, no schema usage for those roles, and no public
  views/RPCs.
- Explicit service-role grants only; `admin_settings` and `audit_logs` are
  inaccessible to anon/authenticated.
- Server-side idempotency helpers: `begin_operation`, `complete_operation`,
  `fail_operation`, payload hashing, and unique payment `operation_id`.
- Admin audit helper with allowlisted-object metadata and size limit.
- Edge Function shared helpers for admin JWT/session verification, input
  validation, idempotency RPC wrappers, and safe HTTP errors.
- pgTAP schema/RLS/idempotency tests, Deno helper tests, and backend CI job.
- Local Supabase setup and security model documented in `supabase/README.md`.
- Option A+ extension: `read_devices` table with active-device uniqueness,
  expiry/revocation, and service-role-only access.
- Device-token helpers: opaque `dr_dev_` token generation, SHA-256 hashing,
  expiry/revocation checks, and `last_seen_at` touch.
- Read-only device visibility approved: name, phone, notes, debt/group data,
  and payment history; no admin/audit/registry data.
- Enrollment/revocation endpoint + UI remain scheduled for Sprint 06; read-only
  pull endpoint remains scheduled for Sprint 07.

### Sprint 02 — Local database & repository (12 November 2026)

- Drift/SQLite schema version 1 with `customers`, `debt_groups`, `debts`,
  `payments`, `sync_queue`, and `sync_metadata`.
- Local schema mirrors cloud fields and adds `sync_state`, `server_updated_at`,
  and `version` for mutable entities.
- Foreign keys enabled; customer/debt references restrict deletion, group
  references set null; payments use append-only SQLite triggers.
- Drift code generated and committed for reproducible builds.
- Domain entities, repository contracts, DAOs, and repository providers.
- Repository reads are reactive Drift streams.
- Every local mutation runs inside a SQLite transaction and inserts its outbox
  entry with a stable operation ID; forced outbox failure rolls back the entity.
- Local version conflicts throw a typed `AppException` instead of overwriting.
- Payment repository is append-only; no update/delete API is exposed.
- `sync_queue` stores operation metadata, retry count, status, error code, and
  next retry time; `sync_metadata` stores sync cursors.
- Database bootstrap opens the local DB before the app shell and shows a
  loading/error screen if opening fails.
- Development-only demo seed is opt-in with `SEED_DEMO_DATA=true`; demo rows are
  marked synced and do not create outbox entries.
- Local repository tests cover atomic writes, outbox, reactive reads, version
  conflicts, append-only payments, seeding, and schema creation.

## Files changed

### Sprint 00

- `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`, `.gitignore`
- `README.md`, `config/app_config.example.json`
- `.github/workflows/ci.yml`
- `lib/main.dart`
- `lib/app/` (app, router, navigation, theme, shell, drawer, error screen,
  providers)
- `lib/core/` (config, errors, logging, network, security notes, currency
  formatter)
- `lib/features/` (dashboard, debts, debt_groups, customers, reminders,
  settings, admin placeholders)
- `lib/shared/widgets/feature_placeholder.dart`
- `test/app/app_navigation_test.dart`
- `test/core/config/app_config_test.dart`
- `test/core/utils/currency_formatter_test.dart`
- `android/app/src/main/AndroidManifest.xml` (app label)

### Sprint 01

- `supabase/config.toml`
- `supabase/migrations/20261112120000_core_functions.sql`
- `supabase/migrations/20261112120100_business_tables.sql`
- `supabase/migrations/20261112120200_security.sql`
- `supabase/migrations/20261112120300_idempotency_audit.sql`
- `supabase/migrations/20261112120400_read_devices.sql`
- `supabase/tests/schema_security.test.sql`
- `supabase/tests/idempotency.test.sql`
- `supabase/tests/read_devices.test.sql`
- `supabase/functions/deno.json`
- `supabase/functions/.env.example`
- `supabase/functions/_shared/auth.ts`
- `supabase/functions/_shared/crypto.ts`
- `supabase/functions/_shared/device_auth.ts`
- `supabase/functions/_shared/validation.ts`
- `supabase/functions/_shared/idempotency.ts`
- `supabase/functions/_shared/http.ts`
- `supabase/functions/_shared/*_test.ts`
- `supabase/README.md`
- `.github/workflows/ci.yml` (backend job)
- `README.md` (backend section)
- `plans/DECISIONS.md` (D-004 s.d. D-008)
- `plans/01_PRODUCT_REQUIREMENTS.md` (read-only devices)
- `plans/03_DATABASE_AND_SECURITY.md` (implemented schema and Option A+)
- `plans/04_OFFLINE_SYNC.md` (read-only device pull path)
- `plans/05_UI_UX_SPEC.md` (device enrollment UI)
- `plans/README.md`
- `plans/sprints/SPRINT_01_CLOUD_SCHEMA_SECURITY.md`
- `plans/sprints/SPRINT_06_ADMIN_SECURITY.md`
- `plans/sprints/SPRINT_07_OFFLINE_SYNC.md`
- `plans/STATUS.md`

### Sprint 02

- `pubspec.yaml`, `pubspec.lock` (Drift, drift_flutter, uuid, drift_dev,
  build_runner)
- `lib/data/local/app_database.dart`
- `lib/data/local/app_database.g.dart` (generated Drift code)
- `lib/data/local/daos/` (customer, debt group, debt, payment, sync queue,
  sync metadata)
- `lib/data/local/dev_seed.dart`
- `lib/data/repositories/` (customer, group, debt, payment implementations,
  mappers, payloads, support)
- `lib/domain/entities/` (customer, debt, debt group, payment, sync state)
- `lib/domain/repositories/` (customer, debt group, debt, payment contracts)
- `lib/domain/validation/entity_validation.dart`
- `lib/app/bootstrap.dart`
- `lib/app/providers.dart` (database/repository providers)
- `lib/main.dart` (DB bootstrap)
- `lib/core/config/app_config.dart` (`SEED_DEMO_DATA`)
- `lib/core/errors/app_exception.dart` (`notFound`)
- `config/app_config.example.json`
- `test/data/local/app_database_test.dart`
- `test/data/repositories/repository_test.dart`
- `test/app/bootstrap_test.dart`
- `test/core/config/app_config_test.dart`
- `linux/flutter/generated_plugins.cmake`,
  `windows/flutter/generated_plugins.cmake` (generated plugin registrants)
- `.gitignore` (`android/.kotlin`)
- `README.md` (local database section)
- `plans/DECISIONS.md` (D-009, D-010)
- `plans/03_DATABASE_AND_SECURITY.md` (implemented local schema)
- `plans/sprints/SPRINT_02_LOCAL_DATABASE_REPOSITORY.md`
- `plans/STATUS.md`

## Test evidence

Commands run on 12 November 2026:

```text
flutter pub get                                              passed
dart run build_runner build                                  passed
dart format --output=none --set-exit-if-changed .            passed
flutter analyze                                              no issues
flutter test                                                 passed, 24 tests
flutter build apk --debug                                    passed
adb install -r build/app/outputs/flutter-apk/app-debug.apk   passed (I2505, Sprint 00)

supabase db start                                            passed
supabase db reset                                            passed
supabase test db                                             passed, 92 pgTAP assertions
supabase db lint                                             no schema errors
deno fmt --check                                             passed
deno check _shared/*.ts                                      passed
deno lint                                                    passed
deno test                                                    passed, 43 tests
```

On-device verification: Sprint 00 launched on I2505 (Android 16, API 36), the
Dashboard rendered, the drawer opened, and navigation to Group Hutang worked.
Sprint 02 verified database bootstrap and seed via widget tests; the debug APK
builds, but no Android device was connected to launch the Sprint 02 APK.

Backend verification: a fresh local database was recreated from all five
migrations; anon/authenticated access failed at schema, table, and function
level; admin settings/audit logs were inaccessible; idempotency replay and
payload-conflict paths passed; read-device enrollment, revocation, expiry, and
token uniqueness constraints passed.

## Blockers / known limitations

- No active blockers for Sprint 02.
- No Android device was connected during Sprint 02; APK build and DB bootstrap
  tests passed, but the Sprint 02 APK has not been launched on device.
- Cloud Supabase project has not been linked or pushed. No owner-provided cloud
  credentials were used, and `db push` was not run.
- Edge Functions currently contain shared helpers only; PIN verification,
  session issuance, and device enrollment are Sprint 06; sync/pull endpoints are
  Sprint 07.
- No public read exists by design. Read-only devices must be enrolled by an
  admin before they can pull cloud data; until their enrollment/pull endpoint is
  implemented, non-admin devices can only read cached local data.
- Local SQLite is not encrypted yet. It contains customer contact data and
  notes; device-level app lock/encryption remains an owner decision.
- Schema version 1 has no upgrade path yet. `onUpgrade` intentionally throws;
  future schema changes require explicit migration steps and tests.
- Stale `processing` operations and expired admin session cleanup will be
  handled by the sync/session sprints; no background cleanup job exists yet.
- Outbox entries are queued but not sent yet; sync is Sprint 07.
- Demo seed is available only with `SEED_DEMO_DATA=true` in development.

## Decisions

- One admin.
- Shared cloud data.
- No ordinary user login.
- Simple groups only (no subgroup).
- Offline-first with Drift/SQLite and outbox.
- No public read in v1; RLS deny-all for anon/authenticated.
- Read-only device enrollment (Option A+) uses revocable opaque device tokens.
- Enrolled read-only devices may see phone/notes/debt/payment history.
- Admin mutations must be server-authorized through Edge Functions.
- Admin sessions use short-lived HS256 JWTs with server-side hashed sessions.
- Idempotency uses `operation_id` + stable payload hash + registry.
- Local-first writes use Drift schema v1 with an atomic outbox.
- Demo seed is opt-in only with `SEED_DEMO_DATA=true` in development.
- Environment config uses `--dart-define`; see `plans/DECISIONS.md`.

## Owner decisions still pending

- [ ] Confirm whether device-level app lock/local SQLite encryption is required.
- [ ] Confirm read-only device token lifetime and enrollment UX.
- [ ] Confirm PIN length and recovery/rotation process.
- [ ] Confirm exact reminder schedule and whether exact alarms are required.
- [ ] Confirm overpayment policy (default reject).
- [ ] Confirm delete/archive policy for debts, groups, customers.

Resolved: public data visibility — no anon/public read; admin-enrolled read-only
devices may pull phone/notes/debt/payment data (12 November 2026).

## Next step

1. Request owner approval before starting Sprint 03 (Groups & customers).
2. Sprint 03 will build group/customer screens on top of the Sprint 02
   repositories, including validation, archive/restore, search, empty/loading/
   error/offline states, and tests.
