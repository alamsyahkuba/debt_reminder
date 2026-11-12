# Sprint 02 — Local Database & Repository

## Goal
Implement Drift database, domain models, repositories, and local-first read/write foundation.

## Tasks
- [x] Define Drift tables mirroring cloud entities.
- [x] Add local sync metadata and outbox table.
- [x] Configure DB location and lifecycle.
- [x] Add schema version and migration strategy.
- [x] Generate Drift code.
- [x] Create domain entities and repository interfaces.
- [x] Implement local DAOs.
- [x] Implement repository reads as Drift streams.
- [x] Implement atomic local writes + outbox insertion.
- [x] Add unit/repository tests.
- [x] Add database seed/demo data for development only.

## Acceptance criteria
- App opens with local DB.
- Local test data can be queried reactively.
- Entity mutation and outbox insert are atomic.
- DB migration tests pass.
- UI does not call Supabase directly.

## Verification (12 November 2026)

| Check | Result |
|---|---|
| `dart run build_runner build` | Passed; Drift schema generated |
| `dart format --output=none --set-exit-if-changed .` | Passed |
| `flutter analyze` | Passed, no issues |
| `flutter test` | Passed; 24 tests |
| `flutter build apk --debug` | Passed; debug APK built |
| App opens with local DB | Bootstrap widget test passed; physical Android launch not verified because no device was connected |
| Reactive local reads | Passed through Drift stream tests |
| Atomic entity + outbox write | Passed; forced outbox failure rolled back entity |
| Migration/schema tests | Passed for schema v1 creation and file reopen; no previous schema version exists yet |
| UI direct Supabase access | None; no Supabase dependency in Flutter |

Known limitation: schema v1 currently has no upgrade migration. The database
`onUpgrade` intentionally fails until an explicit migration is added; every
future schema change must include a migration test.
