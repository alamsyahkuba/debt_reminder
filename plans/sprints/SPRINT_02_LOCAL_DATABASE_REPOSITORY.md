# Sprint 02 — Local Database & Repository

## Goal
Implement Drift database, domain models, repositories, and local-first read/write foundation.

## Tasks
- [ ] Define Drift tables mirroring cloud entities.
- [ ] Add local sync metadata and outbox table.
- [ ] Configure DB location and lifecycle.
- [ ] Add schema version and migration strategy.
- [ ] Generate Drift code.
- [ ] Create domain entities and repository interfaces.
- [ ] Implement local DAOs.
- [ ] Implement repository reads as Drift streams.
- [ ] Implement atomic local writes + outbox insertion.
- [ ] Add unit/repository tests.
- [ ] Add database seed/demo data for development only.

## Acceptance criteria
- App opens with local DB.
- Local test data can be queried reactively.
- Entity mutation and outbox insert are atomic.
- DB migration tests pass.
- UI does not call Supabase directly.
