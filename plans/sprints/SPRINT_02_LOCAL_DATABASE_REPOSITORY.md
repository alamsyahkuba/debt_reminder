# Sprint 02 — Local Database & Repository

> **Sprint 02R complete (13 November 2026):** local schema reset without
> customers; customer data layer and device-token artifacts removed. Public
> clients use pull-only; admin mutations use the outbox.

## Goal
Implement the revised Drift database, domain models, repositories, public pull,
and local-first read/write foundation.

## Tasks
- [x] Define Drift tables for groups, debts, payments, sync queue, and sync
      metadata. Do not define customers.
- [x] Remove `customer_id` from local debts.
- [x] Add local sync metadata and outbox table for admin mutations only.
- [x] Configure DB location, lifecycle, and reset/migration strategy.
- [x] Generate Drift code.
- [x] Create domain entities and repository interfaces for groups, debts, and
      payments.
- [x] Implement local DAOs.
- [x] Implement repository reads as Drift streams.
- [x] Implement atomic admin writes + outbox insertion.
- [ ] Implement public pull merge without creating outbox entries
      (Sprint 07).
- [x] Remove customer repository/entity/DAO and customer screens/tests.
- [x] Add unit/repository tests for revised entities and public pull.
- [x] Add development seed data for groups, debts, and payments only.

## Acceptance criteria
- [x] App opens with the revised local DB.
- [x] No customer table/entity/repository exists.
- [x] Local group/debt/payment data can be queried reactively.
- [x] Admin entity mutation and outbox insert are atomic.
- [ ] Public pull does not create outbox entries (Sprint 07).
- [x] DB reset/migration tests pass.
- [x] UI does not call Supabase directly.

## Verification (13 November 2026)

| Check | Result |
|---|---|
| `dart run build_runner build` | Passed; Drift schema v2 generated |
| `dart format --output=none --set-exit-if-changed .` | Passed |
| `flutter analyze` | Passed, no issues |
| `flutter test` | Passed; 32 tests |
| `flutter build apk --debug` | Passed |
| Schema v2 | Passed; `customers` and `customer_id` absent |
| Destructive v1→v2 migration | Passed; old customer schema dropped and recreated |
| Atomic entity + outbox write | Passed; forced outbox failure rolled back entity |
| Public pull | Not implemented yet; public pull/UI is Sprint 07 |
| UI direct Supabase access | None |

Known limitation: public pull/UI mode is scheduled with Sprint 07; the local
schema and repository boundary are ready.
