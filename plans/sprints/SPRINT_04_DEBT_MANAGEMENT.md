# Sprint 04 — Debt Management

## Goal
Implement debt CRUD, search, filters, and debt detail without a customer entity.

## Tasks
- [x] Debt entity and validation.
- [x] Debt create/edit form.
- [x] Debt list and detail screen.
- [x] Group selector and Unassigned behavior.
- [x] Remove customer selector and customer validation.
- [x] Search by title/notes.
- [x] Filters by group, due date, derived payment state.
- [x] Sort options: due date, newest, amount, group.
- [x] Archive debt.
- [x] Derive paid/outstanding/status from payments.
- [x] Public read boundary documented; Flutter public pull remains Sprint 07.
- [x] Tests for calculations, validation, and UI flow.

## Acceptance criteria
- [x] Debt can be created offline without a customer.
- [x] Invalid amount is rejected.
- [x] Debt appears in the correct group or Unassigned.
- [x] Search/filter work offline.
- [x] Derived status is consistent with payment total and due date.
- [x] No customer table, selector, detail section, or dependency exists.
- [ ] Public Flutter read UI/pull — Sprint 07.

## Verification (13 November 2026)

| Check | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed .` | Passed |
| `flutter analyze` | Passed, no issues |
| `flutter test` | Passed; 36 tests |
| `flutter build apk --debug` | Passed |
| Debt create/edit form | Passed |
| Debt list/search/filter/sort | Implemented; search and status display tested |
| Debt detail | Passed; group, amounts, payment history, archive |
| Derived status | Passed for unpaid/partial/paid/overdue |
| No customer dependency | Passed |
| Public Flutter mode | Deferred to Sprint 07 |
