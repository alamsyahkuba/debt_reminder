# Sprint 09 — QA, Hardening & Release

## Goal
Prepare a stable Android release candidate for the revised public-read product,
including hard-delete safety, deletion reconciliation, and admin backup/export.

## Tasks
- [ ] Run all unit/widget/integration tests.
- [ ] Run Flutter analyze and formatting.
- [ ] Review public RPCs, RLS, and Edge Function security.
- [ ] Verify anon can read all approved business data but cannot mutate.
- [ ] Verify internal tables/RPCs are inaccessible to anon.
- [ ] Verify no customer table/entity/UI remains.
- [ ] Verify no read_devices/device enrollment remains.
- [ ] Verify no secrets in repo/build artifacts.
- [ ] Test fresh install and database reset.
- [ ] Test offline/online transitions and public pull.
- [ ] Test Android notification permissions/background behavior.
- [ ] Implement hard delete group/debt according to D-021.
- [ ] Add server/local/UI delete mutation and audit.
- [ ] Implement full-pull deletion reconciliation at startup (max once/24h) and
      manual sync; preserve pending/conflict rows.
- [ ] Implement admin JSON backup/export.
- [ ] Implement admin-only restore-merge with validation and preview.
- [ ] Add tests for hard delete, full-pull deletion, export, and restore.
- [ ] Document no app lock/SQLite encryption and no PIN recovery.
- [ ] Add app icon, splash, package name, version.
- [ ] Configure release signing outside repo.
- [ ] Document known limitations and release checklist.
- [ ] Deploy cloud migrations and Edge Functions after credentials are set.

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
- Release keystore and signing credentials outside the repository.
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
