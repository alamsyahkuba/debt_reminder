# Sprint 09 — QA, Hardening & Release

## Goal
Prepare a stable Android release candidate for the revised public-read product,
including hard-delete safety, deletion reconciliation, and admin backup/export.

## Tasks
- [x] Run unit and widget tests.
- [x] Run integration/device tests on the release candidate.
- [x] Run Flutter analyze and formatting.
- [x] Review public RPCs, RLS, and Edge Function security.
- [x] Verify anon can read all approved business data but cannot mutate.
- [x] Verify internal tables/RPCs are inaccessible to anon.
- [x] Verify no customer table/entity/UI remains.
- [x] Verify no read_devices/device enrollment remains.
- [x] Verify no secrets in repo/build artifacts.
- [x] Test fresh install and database reset on a physical Android device.
- [x] Test offline/online transitions and public pull on a physical device.
- [x] Test admin flow on a physical Android device (owner-reported passed).
- [x] Test Android notification permissions/background behavior on device.
- [x] Implement hard delete group/debt according to D-021.
- [x] Add server/local/UI delete mutation and audit.
- [x] Implement full-pull deletion reconciliation at startup (max once/24h) and
      manual sync; preserve pending/conflict rows.
- [x] Implement admin JSON backup/export.
- [x] Implement admin-only restore-merge with validation and preview.
- [x] Add tests for hard delete, full-pull deletion, export, and restore.
- [x] Document no app lock/SQLite encryption and no PIN recovery.
- [x] Add app icon, splash, package name, version.
- [x] Configure release signing outside repo.
- [x] Document known limitations and release checklist.
- [x] Deploy cloud migrations and Edge Functions after credentials are set.

Owner test sign-off: I2505 (`10DG3404HM000HH`), 14 November 2026. Seluruh
pemeriksaan perangkat yang direncanakan dilaporkan lolos oleh owner
(owner-reported, bukan otomasi).

## Hard-delete policy
- Group delete moves debts to Unassigned, then deletes the group.
- Debt hard delete is allowed only when the debt has no payments.
- Debt with payments can only be archived.
- Payments remain append-only and are never deleted.
- Hard delete requires explicit confirmation and server audit.
- Backup/export is recommended before hard delete.

## Backup/restore policy
- Admin-only JSON export with `schema_version`, `exported_at`, groups, debts,
  and payments.
- No internal metadata, session, audit, token, `version`, or `operation_id` in
  the export.
- Restore-merge adds missing records by ID; it does not overwrite or delete
  existing records.
- Full destructive cloud restore is out of scope for v1.

## Release inputs required from owner
- Supabase project ref and deployment access.
- `ADMIN_SESSION_JWT_SECRET`, `ADMIN_PIN_PEPPER`, and temporary
  `ADMIN_INITIAL_PIN`.
- Client `SUPABASE_URL` and anon/publishable key.
- Final application ID, app name, version, icon, and splash.
- Release keystore and signing credentials outside the repository. Current
  `android/key.properties` points to a valid upload keystore; the release
  APK release has been built and signature-verified. AAB/Play Console are out
  of scope for v1 distribution.
- Physical Android device(s) for notification, WorkManager, and fresh-install
  verification.

## Acceptance criteria
- Critical tests pass.
- No known critical security issue.
- Release build succeeds.
- Fresh install and reset paths tested.
- Public read and anon mutation denial verified.
- No customer or device-enrollment artifacts remain.
- Hard delete never removes payments or a debt that has payments.
- Deleted server rows are reconciled on other devices without deleting pending
  local work.
- Backup export works and restore-merge validates references and does not
  silently overwrite data.
- No app lock/encryption or PIN recovery is documented as a known limitation.
- Owner signs off on public data visibility, PIN reset runbook, and backup
  policy.

## Verification gate (to run during Sprint 09)
```text
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build apk --debug
flutter build apk --release
npx supabase@3.1.0 test db
npx supabase@3.1.0 db lint
npx supabase@3.1.0 functions deploy admin-pin admin-sync
```

Plus manual Android checks for notifications, exact alarms, boot rescheduling,
timezone changes, WorkManager, and offline/online transitions.
