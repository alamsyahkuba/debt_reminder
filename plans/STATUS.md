# Project Status

## Current phase

Sprint 00 — Foundation and Sprint 01 — Cloud schema & security are complete,
including the read-only device enrollment foundation (Option A+). Ready for
owner approval before Sprint 02.

## Sprint status

- [x] Sprint 00 — Foundation
- [x] Sprint 01 — Cloud schema & security
- [ ] Sprint 02 — Local database & repository
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

## Test evidence

Commands run on 12 November 2026:

```text
flutter pub get                                              passed
dart format --output=none --set-exit-if-changed .            passed
flutter analyze                                              no issues
flutter test                                                 passed, 7 tests
flutter build apk --debug                                    passed
adb install -r build/app/outputs/flutter-apk/app-debug.apk   passed (I2505)

supabase db start                                            passed
supabase db reset                                            passed
supabase test db                                             passed, 92 pgTAP assertions
supabase db lint                                             no schema errors
deno fmt --check                                             passed
deno check _shared/*.ts                                      passed
deno lint                                                    passed
deno test                                                    passed, 43 tests
```

On-device verification: the app launched on I2505 (Android 16, API 36), the
Dashboard rendered, the drawer opened, and navigation to Group Hutang worked.

Backend verification: a fresh local database was recreated from all five
migrations; anon/authenticated access failed at schema, table, and function
level; admin settings/audit logs were inaccessible; idempotency replay and
payload-conflict paths passed; read-device enrollment, revocation, expiry, and
token uniqueness constraints passed.

## Blockers / known limitations

- No active blockers for Sprint 01.
- Cloud Supabase project has not been linked or pushed. No owner-provided cloud
  credentials were used, and `db push` was not run.
- Edge Functions currently contain shared helpers only; PIN verification,
  session issuance, and device enrollment are Sprint 06; sync/pull endpoints are
  Sprint 07.
- No public read exists by design. Read-only devices must be enrolled by an
  admin before they can pull cloud data; until their enrollment/pull endpoint is
  implemented, non-admin devices can only read cached local data.
- Stale `processing` operations and expired admin session cleanup will be
  handled by the sync/session sprints; no background cleanup job exists yet.
- Local database seed/demo data is intentionally absent until Sprint 02.

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
- Environment config uses `--dart-define`; see `plans/DECISIONS.md`.

## Owner decisions still pending

- [ ] Confirm whether device-level app lock is required.
- [ ] Confirm read-only device token lifetime and enrollment UX.
- [ ] Confirm PIN length and recovery/rotation process.
- [ ] Confirm exact reminder schedule and whether exact alarms are required.
- [ ] Confirm overpayment policy (default reject).
- [ ] Confirm delete/archive policy for debts, groups, customers.

Resolved: public data visibility — no anon/public read; admin-enrolled read-only
devices may pull phone/notes/debt/payment data (12 November 2026).

## Next step

1. Request owner approval before starting Sprint 02 (Local database &
   repository).
2. Sprint 02 will add Drift/SQLite, domain entities, repository contracts,
   atomic local writes + outbox, migrations, and local tests.
