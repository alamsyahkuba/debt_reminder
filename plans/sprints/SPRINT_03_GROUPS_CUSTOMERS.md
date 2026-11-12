# Sprint 03 — Groups (Customer Scope Removed)

> **Revised 12 November 2026:** customer management is removed. Group features
> remain. The filename is kept to avoid creating a new plan file.

## Goal
Implement and finish simple group management on the revised group/debt/payment
model.

## Tasks
- [ ] Group domain entity, validation, repository, DAO.
- [ ] Group list screen with color/icon/sort order.
- [ ] Group create/edit form.
- [ ] Group detail summary and debt list.
- [ ] Archive/restore group.
- [ ] Delete group with explicit Unassigned debt behavior and confirmation.
- [ ] Move debt to/from group action.
- [ ] Remove all customer screens, providers, routes, repository, entity, DAO,
      and tests.
- [ ] Remove customer references from group summaries and navigation.
- [ ] Empty/loading/error/offline states for group screens.
- [ ] Tests for group behavior and public read.

## Acceptance criteria
- Group has no parent/subgroup.
- Group can be created offline and appears immediately.
- Group archive preserves debts.
- Group delete never deletes debts.
- There is no customer menu, screen, entity, or route.
- Local group operations create outbox records.
- Public users can read groups without mutation access.

## Existing implementation (superseded in part)

Group UI and repository behavior were implemented under the previous plan and
can be retained selectively. Customer list/form/detail/search/archive and
customer summaries are removed by the revised plan.

## Verification

The previous group/customer test suite is historical. Revised verification must
run after customer removal and public read integration.
