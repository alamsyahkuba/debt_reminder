# Sprint 03 — Groups (Customer Scope Removed)

> **Sprint 03R complete (13 November 2026):** customer management is removed.
> Group features remain. The filename is kept to avoid creating a new plan file.

## Goal
Implement and finish simple group management on the revised group/debt/payment
model.

## Tasks
- [x] Group domain entity, validation, repository, DAO.
- [x] Group list screen with color/icon/sort order.
- [x] Group create/edit form.
- [x] Group detail summary and debt list.
- [x] Archive/restore group.
- [x] Delete group with explicit Unassigned debt behavior and confirmation.
- [x] Move debt to/from group action.
- [x] Remove all customer screens, providers, routes, repository, entity, DAO,
      and tests.
- [x] Remove customer references from group summaries and navigation.
- [x] Empty/loading/error/offline states for group screens.
- [x] Tests for group behavior and customer-free data flow.

## Acceptance criteria
- [x] Group has no parent/subgroup.
- [x] Group can be created offline and appears immediately.
- [x] Group archive preserves debts.
- [x] Group delete never deletes debts.
- [x] There is no customer menu, screen, entity, or route.
- [x] Local group operations create outbox records.
- [ ] Public read-only UI mode and public pull — scheduled with Sprint 07.

## Verification (13 November 2026)

| Check | Result |
|---|---|
| `flutter analyze` | Passed, no issues |
| `flutter test` | Passed; 32 tests |
| `flutter build apk --debug` | Passed |
| Group create/edit/archive | Passed |
| Group delete | Passed; debts moved to Unassigned, not deleted |
| Customer removal | Passed; no customer files/routes/tests |
| Group flow widget tests | Passed |
| Public mode | Deferred to Sprint 07 |
