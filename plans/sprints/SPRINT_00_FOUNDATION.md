# Sprint 00 — Foundation

## Goal
Create a clean Flutter project foundation and developer workflow.

## Prerequisites
- Flutter SDK installed.
- Android toolchain configured.
- Git repository initialized.

## Tasks
- [ ] Inspect repository and preserve existing work.
- [ ] Configure `pubspec.yaml`, SDK constraints, dependencies.
- [ ] Create app entry point and Material 3 theme.
- [ ] Configure Riverpod ProviderScope.
- [ ] Configure GoRouter with placeholder routes.
- [ ] Create core folder structure from architecture.
- [ ] Add environment/config loading without committing secrets.
- [ ] Add lint rules and formatting conventions.
- [ ] Add basic app shell and drawer.
- [ ] Add placeholder Dashboard, Groups, Debts, Customers, Settings, Admin PIN screens.
- [ ] Add README with setup/run instructions.
- [ ] Add CI workflow for format/analyze/test if repository uses GitHub Actions.

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
