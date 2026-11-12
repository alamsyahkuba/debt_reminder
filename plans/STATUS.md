# Project Status

## Current phase

Sprint 00 — Foundation is complete and verified on an Android device. Ready for
owner approval before Sprint 01.

## Sprint status

- [x] Sprint 00 — Foundation
- [ ] Sprint 01 — Cloud schema & security
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
- No Supabase, Drift, CRUD, authentication, or sync code added.
- Debug APK installed and launched on I2505 (Android 16, API 36); Dashboard
  rendered and drawer navigation to Group Hutang verified.

## Files changed

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
- `plans/DECISIONS.md`
- `plans/sprints/SPRINT_00_FOUNDATION.md`
- `plans/STATUS.md`
- `android/app/src/main/AndroidManifest.xml` (app label)

## Test evidence

Commands run on 12 November 2026:

```text
flutter pub get                                              passed
dart format --output=none --set-exit-if-changed .            passed
flutter analyze                                              no issues
flutter test                                                 passed, 7 tests
flutter build apk --debug                                    passed
adb install -r build/app/outputs/flutter-apk/app-debug.apk   passed (I2505)
flutter devices                                              I2505 detected
```

APK output: `build/app/outputs/flutter-apk/app-debug.apk`.

On-device verification: the app launched on I2505 (Android 16, API 36), the
Dashboard rendered, the drawer opened, and navigation to Group Hutang worked.

## Blockers / known limitations

- No active blockers for Sprint 00.
- Linux desktop run is unavailable because the environment lacks clang, CMake,
  ninja, and pkg-config; Android device verification succeeded.
- Supabase, Drift, admin authentication, CRUD, and sync are intentionally not
  implemented yet.

## Decisions

- One admin.
- Shared cloud data.
- No ordinary user login.
- Simple groups only (no subgroup).
- Offline-first with Drift/SQLite and outbox.
- Public reads must be explicitly approved and field-limited.
- Admin mutations must be server-authorized.
- Environment config uses `--dart-define`; see `plans/DECISIONS.md`.

## Owner decisions still pending

- [ ] Confirm which debt/customer fields are visible to anonymous users.
- [ ] Confirm whether public debt data is truly accessible to anyone or app should have a device/app access gate.
- [ ] Confirm PIN length and recovery/rotation process.
- [ ] Confirm exact reminder schedule and whether exact alarms are required.
- [ ] Confirm overpayment policy (default reject).
- [ ] Confirm delete/archive policy for debts, groups, customers.

## Next step

1. Request owner approval before starting Sprint 01 (Cloud schema & security).
2. Sprint 01 requires owner confirmation of public data visibility before
   finalizing read policies.
