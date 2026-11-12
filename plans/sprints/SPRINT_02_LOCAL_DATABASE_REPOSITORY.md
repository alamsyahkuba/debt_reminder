# Sprint 02 — Local Database & Repository

> **Revised 12 November 2026:** local schema must be reset without customers and
> read-only device data. Public clients use pull-only; admin mutations use the
> outbox.

## Goal
Implement the revised Drift database, domain models, repositories, public pull,
and local-first read/write foundation.

## Tasks
- [ ] Define Drift tables for groups, debts, payments, sync queue, and sync
      metadata. Do not define customers.
- [ ] Remove `customer_id` from local debts.
- [ ] Add local sync metadata and outbox table for admin mutations only.
- [ ] Configure DB location, lifecycle, and reset/migration strategy.
- [ ] Generate Drift code.
- [ ] Create domain entities and repository interfaces for groups, debts, and
      payments.
- [ ] Implement local DAOs.
- [ ] Implement repository reads as Drift streams.
- [ ] Implement atomic admin writes + outbox insertion.
- [ ] Implement public pull merge without creating outbox entries.
- [ ] Remove customer repository/entity/DAO and customer screens/tests.
- [ ] Add unit/repository tests for revised entities and public pull.
- [ ] Add development seed data for groups, debts, and payments only.

## Acceptance criteria
- App opens with the revised local DB.
- No customer table/entity/repository exists.
- Local group/debt/payment data can be queried reactively.
- Admin entity mutation and outbox insert are atomic.
- Public pull does not create outbox entries.
- DB reset/migration tests pass.
- UI does not call Supabase directly.

## Verification (existing implementation, superseded)

| Check | Previous result |
|---|---|
| `flutter test` | 34 tests under customer/device-enrollment model |
| `flutter build apk --debug` | Passed under old schema |
| Local schema | v1 with customers; not compliant with revised plan |
| Public pull | Not implemented |
| Outbox | Admin/customer writes only; must be revised |

The existing implementation must be reset and the tests updated.
