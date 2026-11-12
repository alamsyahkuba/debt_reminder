# Testing & Acceptance Criteria

## 1. Test layers

- Unit: domain calculations, validation, status derivation, currency/date helpers, conflict resolver.
- Repository: local write/outbox atomicity, local stream, sync mapping.
- Database: Drift constraints and migrations.
- Edge Function: PIN validation, auth/session, payload validation, idempotency, version conflicts.
- RLS: anon can only read approved data; anon cannot mutate or read secret tables.
- Widget: dashboard, group list/detail, debt form, payment form, admin PIN.
- Integration: offline create → reconnect → sync → restart → verify.
- Manual Android: notification permission, exact alarm behavior if used, background restrictions.

## 2. Critical acceptance criteria

### Group
- Admin creates group offline; it appears immediately.
- Group syncs exactly once after reconnect.
- Debt can be assigned/moved between groups.
- Group deletion follows explicit policy and never silently deletes debts.
- Archived group remains available for historical debt.
- Group totals match underlying debts/payments.

### Debt/payment
- Payment amount must be positive.
- Overpayment rejected by default.
- Duplicate sync retry does not duplicate payment.
- Paid/outstanding totals are correct.
- Payment history remains append-only.

### Offline
- App opens and shows cached data without network.
- CRUD local operation works offline after admin local unlock.
- Queue survives app force-close/restart.
- Retry works after internet returns.
- Conflict is visible and not silently discarded.

### Security
- No service role key in APK/source.
- Anon cannot mutate database.
- PIN hash is not exposed.
- Admin endpoints reject missing/expired/invalid session.
- Rate limit PIN attempts.
- Audit logs exclude secrets.

### Reminder
- Reminder schedule is created for eligible debts.
- Schedule updates after due date changes.
- Schedule cancels after paid/archive.
- Permission denied state is explained.
- Notification behavior documented for Android battery/background constraints.

## 3. Definition of Done per sprint
- Scope implemented.
- Acceptance criteria checked.
- Automated tests pass.
- `flutter analyze` passes without new errors.
- Relevant migration/Edge Function tests pass.
- README/docs updated.
- No secrets committed.
- Sprint status updated with evidence and known limitations.
