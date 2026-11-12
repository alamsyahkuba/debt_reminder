# Sprint 03 — Debt Groups & Customers

## Goal
Implement simple groups and customer management.

## Tasks
- [x] Group domain entity, validation, repository, DAO.
- [x] Group list screen with color/icon/sort order.
- [x] Group create/edit form.
- [x] Group detail summary and debt list placeholder.
- [x] Archive/restore group.
- [x] Delete group with explicit Unassigned debt behavior and confirmation.
- [x] Move debt to/from group action.
- [x] Customer entity and CRUD/archive.
- [x] Customer search.
- [x] Empty/loading/error/offline states.
- [x] Tests for group/customer behavior.

## Acceptance criteria
- Group has no parent/subgroup.
- Group can be created offline and appears immediately.
- Group archive preserves debts.
- Group delete never deletes debts.
- Customer with history cannot be hard-deleted.
- Local group/customer operations create outbox records.

## Verification (12 November 2026)

| Check | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed .` | Passed |
| `flutter analyze` | Passed, no issues |
| `flutter test` | Passed; 34 tests |
| `flutter build apk --debug` | Passed |
| Group create UI | Passed; appears immediately and creates outbox |
| Group edit/archive/restore | Repository tests passed |
| Group delete | Passed; debts moved to Unassigned, not deleted |
| Customer create/archive/search | Passed through UI/widget tests |
| Customer history | Preserved; no hard-delete action exposed |
| Empty/error/offline states | Empty and local-data notice implemented; stream errors have retry |
| Admin PIN gating | Not yet applied; Sprint 06 will gate local management UI before cloud sync |

Known limitation: group/customer management actions are accessible in the local
app before Sprint 06 implements the admin PIN gate. There is no cloud mutation
path yet, so this does not grant server authorization.
