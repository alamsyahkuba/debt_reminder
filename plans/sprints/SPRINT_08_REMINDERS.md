# Sprint 08 — Local Reminders

## Goal
Schedule and maintain local debt due-date notifications for the admin.

## Tasks
- [ ] Configure notification channels and permissions.
- [ ] Configure timezone handling.
- [ ] Implement reminder preferences (H-3, H-1, H, configurable).
- [ ] Schedule reminders for active unpaid/partial debts.
- [ ] Reschedule on due-date change.
- [ ] Cancel on paid/archive.
- [ ] Reconcile schedules at app startup.
- [ ] Handle Android exact alarm permission and fallback.
- [ ] Add reminder management UI for admin.
- [ ] Test permission denied and timezone changes.
- [ ] Ensure public mode only displays due dates and cannot configure reminders.
- [ ] Remove customer/device-enrollment dependencies from reminder flows.

## Acceptance criteria
- Eligible debt reminders are scheduled.
- Changed due date updates reminders.
- Paid/archived debt has no active reminder.
- App explains limitations when OS permission is unavailable.
- Reminder works without internet once scheduled.
- Public users cannot configure or modify reminders.
