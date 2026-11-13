# Sprint 08 — Local Reminders

## Goal
Schedule and maintain local debt due-date notifications for the admin.

## Tasks
- [x] Configure notification channels and permissions.
- [x] Configure timezone handling.
- [x] Implement reminder preferences (H-3, H-1, H, configurable).
- [x] Schedule reminders for active unpaid/partial debts.
- [x] Reschedule on due-date change.
- [x] Cancel on paid/archive.
- [x] Reconcile schedules at app startup.
- [x] Handle Android exact alarm permission and fallback.
- [x] Add reminder management UI for admin.
- [x] Test permission denied and timezone changes.
- [x] Ensure public mode only displays due dates and cannot configure reminders.
- [x] Remove customer/device-enrollment dependencies from reminder flows.

## Acceptance criteria
- [x] Eligible debt reminders are scheduled.
- [x] Changed due date updates reminders.
- [x] Paid/archived debt has no active reminder.
- [x] App explains limitations when OS permission is unavailable.
- [x] Reminder works without internet once scheduled.
- [x] Public users cannot configure or modify reminders.

## Verification (14 November 2026)

| Check | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed .` | Passed |
| `flutter analyze` | Passed, no issues |
| `flutter test` | Passed; 81 tests |
| `flutter build apk --debug` | Passed (compileSdk 37 + core library desugaring) |
| `npx supabase@3.1.0 test db` | Passed; 163 pgTAP assertions (no backend changes) |
| `npx supabase@3.1.0 db lint` | Passed |
| Deno tests | Passed; 64 tests (no backend changes) |
| H-3/H-1/H scheduling | Passed with fake gateway |
| Past reminder skipping | Passed |
| Paid/archived cancellation | Passed |
| Due-date change reschedule | Passed |
| Disabled preferences cancellation | Passed |
| Notification permission denied | Passed; no schedule and explanation shown |
| Timezone change | Passed; UTC instant changes with local zone |
| Exact alarm fallback | Passed; inexact schedule mode used |
| Public read-only reminder screen | Passed; no configuration controls |
| Android device launch | Not verified; no device connected |
| Cloud deployment | Not applicable; reminders are local-only |

## Notes
- Preferences are stored in local SQLite (`local_settings`) and never synced.
- H-3, H-1, and H are represented as offsets 3, 1, 0 with a local time
  (default 09:00).
- Reminder reconciliation cancels and reschedules all local reminders when debt
  data changes, on resume, and at startup.
- Exact alarms are used when allowed; otherwise scheduling falls back to
  inexact alarms and the UI explains the limitation.
- Notification copy explicitly states that a notification is not proof of
  payment.
- Public mode displays due dates only.
