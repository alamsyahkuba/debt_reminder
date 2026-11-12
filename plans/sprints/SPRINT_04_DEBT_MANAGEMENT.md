# Sprint 04 — Debt Management

## Goal
Implement debt CRUD, search, filters, and debt detail without a customer entity.

## Tasks
- [ ] Debt entity and validation.
- [ ] Debt create/edit form.
- [ ] Debt list and detail screen.
- [ ] Group selector and Unassigned behavior.
- [ ] Remove customer selector and customer validation.
- [ ] Search by title/notes.
- [ ] Filters by group, due date, derived payment state.
- [ ] Sort options: due date, newest, amount, group.
- [ ] Archive debt.
- [ ] Derive paid/outstanding/status from payments.
- [ ] Public read of debt data through RPC.
- [ ] Tests for calculations, validation, and public read.

## Acceptance criteria
- Debt can be created offline without a customer.
- Invalid amount is rejected.
- Debt appears in the correct group or Unassigned.
- Search/filter work offline.
- Derived status is consistent with payment total and due date.
- No customer table, selector, detail section, or dependency exists.
- Public users can read debt fields but cannot mutate.
