# Sprint 00 — Foundation

## Goal
Create a clean Flutter project foundation and developer workflow.

## Prerequisites
- Flutter SDK installed.
- Android toolchain configured.
- Git repository initialized.

## Tasks
- [x] Inspect repository and preserve existing work.
- [x] Configure `pubspec.yaml`, SDK constraints, dependencies.
- [x] Create app entry point and Material 3 theme.
- [x] Configure Riverpod ProviderScope.
- [x] Configure GoRouter with placeholder routes.
- [x] Create core folder structure from architecture.
- [x] Add environment/config loading without committing secrets.
- [x] Add lint rules and formatting conventions.
- [x] Add basic app shell and drawer.
- [x] Add placeholder Dashboard, Groups, Debts, Customers, Settings, Admin PIN screens.
- [x] Add README with setup/run instructions.
- [x] Add CI workflow for format/analyze/test if repository uses GitHub Actions.

## Deliverables
- App launches on Android.
- Navigation works between placeholder screens.
- Folder structure established.
- No Supabase business logic yet.

## Acceptance criteria
- `flutter pub get` succeeds.
- `dart format --set-exit-if-changed .` passes.
- `flutter analyze` passes or existing warnings documented.
- `flutter test` passes.
- App launches on emulator/device.

## Out of scope
- Database schema.
- Admin authentication.
- CRUD.
- Offline sync.

## Verification (12 November 2026)

| Check | Result |
|---|---|
| `flutter pub get` | Passed |
| `dart format --output=none --set-exit-if-changed .` | Passed |
| `flutter analyze` | Passed, no issues |
| `flutter test` | Passed, 7 tests |
| `flutter build apk --debug` | Passed, `build/app/outputs/flutter-apk/app-debug.apk` |
| App launch on emulator/device | Passed on I2505 (Android 16, API 36) via `adb install`; Dashboard rendered and drawer navigation to Group Hutang worked |

Sprint 00 acceptance criteria are complete.
