# Testing & Acceptance Criteria

## 1. Test layers

- Unit: domain calculations, validation, status derivation, currency/date
  helpers, conflict resolver.
- Repository: local write/outbox atomicity, local stream, sync mapping.
- Database: Drift constraints, migrations, reset path.
- Edge Function: PIN validation, auth/session, payload validation, idempotency,
  version conflicts.
- RLS: anon can read public RPC, anon cannot read base tables directly, anon
  cannot mutate, internal tables hidden.
- Widget: dashboard, group list/detail, debt form, payment form, admin PIN.
- Integration: public pull, offline create admin → reconnect → sync → restart.
- Manual Android: notification permission, exact alarm behavior if used,
  background restrictions.

## 2. Critical acceptance criteria

### Public read
- Anon can execute public group/debt/payment RPC.
- Public RPC returns all approved business fields.
- Anon cannot SELECT base tables directly.
- Anon cannot INSERT/UPDATE/DELETE.
- Anon cannot access `admin_settings`, `admin_sessions`, `audit_logs`, or
  `operation_registry`.
- Public client can pull data without login or device enrollment.
- Public UI is read-only.

### Group
- Admin creates group offline; it appears immediately.
- Group syncs exactly once after reconnect.
- Debt can be assigned/moved between groups.
- Group deletion moves debts to Unassigned before deleting the group.
- Hard delete requires confirmation and audit.
- Archived group remains available for historical debt.
- Group totals match underlying debts/payments.
- Tidak ada subgroup.

### Debt/payment
- Debt can be created without customer.
- Payment amount must be positive.
- Overpayment rejected by default.
- Duplicate sync retry does not duplicate payment.
- Paid/outstanding totals are correct.
- Payment history remains append-only.
- Debt hard delete is blocked when payments exist.
- Public can read debt/payment data.

### Offline
- App opens and shows cached data without network.
- CRUD admin works offline after a valid admin session/local unlock policy.
- Queue survives app force-close/restart.
- Retry works after internet returns.
- Conflict is visible and not silently discarded.
- Public pull failure keeps cache readable.
- Hard-deleted rows are removed from other devices by full-pull reconciliation;
  pending/conflict rows are preserved.
- Backup JSON exports only business fields; restore-merge validates and does not
  overwrite existing records.

Note: offline local-only PIN unlock is still an owner decision; current UI
requires an online server session before starting local edits. Existing outbox
operations are preserved when that session expires.

### Security
- No service role key in APK/source.
- Anon cannot mutate database.
- PIN hash is not exposed.
- Admin endpoints reject missing/expired/invalid session.
- Rate limit PIN attempts.
- Audit logs exclude secrets.
- Public RPC does not expose internal metadata.
- Tidak ada customer table/entity/UI.
- Tidak ada read_devices/device enrollment.

### Release/security
- No app lock/SQLite encryption is documented as a v1 limitation.
- No PIN recovery UI; server-side reset runbook is documented.
- Public business data sign-off is recorded.

### Reminder
- Reminder schedule is created for eligible debts.
- Schedule updates after due date changes.
- Schedule cancels after paid/archive.
- Permission denied state is explained.
- Notification behavior documented for Android battery/background constraints.

Implemented in Sprint 08 with device-local preferences, local notifications,
timezone-aware scheduling, exact-alarm fallback, startup/resume reconciliation,
and public reminder controls. Reminder preferences never create outbox entries.
Physical-device notification delivery was verified manually on I2505; no new
automated reminder tests are required for the public-access change.

## 3. Reset acceptance
- Fresh local Supabase applies revised migrations.
- Reset removes customers/read_devices/customer_id.
- Local SQLite reset removes customer tables/repositories/screens.
- Public RPC tests pass after reset.
- Anon write tests fail as expected.
- Admin mutation tests pass with valid session and fail without session.

## 4. Definition of Done per sprint
- Scope implemented.
- Acceptance criteria checked.
- Automated tests pass.
- `flutter analyze` passes without new errors.
- Relevant migration/Edge Function tests pass.
- README/docs updated.
- No secrets committed.
- Sprint status updated with evidence and known limitations.
