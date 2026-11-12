# Sprint 03 — Debt Groups & Customers

## Goal
Implement simple groups and customer management.

## Tasks
- [ ] Group domain entity, validation, repository, DAO.
- [ ] Group list screen with color/icon/sort order.
- [ ] Group create/edit form.
- [ ] Group detail summary and debt list placeholder.
- [ ] Archive/restore group.
- [ ] Delete group with explicit Unassigned debt behavior and confirmation.
- [ ] Move debt to/from group action.
- [ ] Customer entity and CRUD/archive.
- [ ] Customer search.
- [ ] Empty/loading/error/offline states.
- [ ] Tests for group/customer behavior.

## Acceptance criteria
- Group has no parent/subgroup.
- Group can be created offline and appears immediately.
- Group archive preserves debts.
- Group delete never deletes debts.
- Customer with history cannot be hard-deleted.
- Local group/customer operations create outbox records.
