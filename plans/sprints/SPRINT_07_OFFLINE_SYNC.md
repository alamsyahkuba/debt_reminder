# Sprint 07 — Offline Sync

## Goal
Synchronize admin mutations through the outbox and pull public data through the
read-only RPC.

## Tasks
- [x] Implement admin sync service and queue claiming.
- [x] Implement Edge Function entity mutation endpoint (`admin-sync`).
- [x] Enforce dependency ordering: group → debt → payment, group delete last.
- [x] Implement stable idempotency with server operation registry and payment
      `operation_id`.
- [x] Implement retry/backoff for transient failures.
- [x] Implement pull cursor and pagination.
- [x] Implement version conflict detection.
- [x] Implement conflict state and reload/keep-local resolution UI.
- [x] Implement connectivity-triggered sync.
- [x] Implement foreground sync and best-effort WorkManager sync.
- [x] Add sync status UI and manual sync.
- [x] Implement public pull via anon read-only RPC.
- [x] Ensure public pull never creates outbox entries or calls mutation
      endpoints.
- [x] Test force-close/restart with pending queue.
- [x] Test duplicate retry and stale-version conflict.
- [x] Test public pull, anon mutation denial, and pagination.

## Acceptance criteria
- [x] Offline admin mutations survive restart.
- [x] Sync sends each logical operation once.
- [x] Duplicate retries do not duplicate payments.
- [x] Stale updates produce conflict, not silent overwrite.
- [x] Pending operations remain intact after authorization/network errors.
- [x] Local data remains usable while sync is failing.
- [x] Public devices pull approved business data without login or enrollment.
- [x] Public pull cannot mutate data.
- [x] No customer dependency exists in sync ordering.

## Verification (13 November 2026)

| Check | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed .` | Passed |
| `flutter analyze` | Passed, no issues |
| `flutter test` | Passed; 68 tests |
| `flutter build apk --debug` | Passed |
| `deno fmt --check` / `deno check` / `deno lint` | Passed |
| `deno test --allow-env --allow-net supabase/functions` | Passed; 64 tests |
| `npx supabase@3.1.0 test db` | Passed; 163 pgTAP assertions |
| `npx supabase@3.1.0 db lint` | Passed |
| Local `admin-sync` integration | Passed |
| Group/debt/payment create | 200 / 200 / 200 |
| Payment replay | 200, one payment row |
| Stale debt update | 409 `version_conflict`, server version 2 |
| Public page RPC | 200, one group |
| Android device launch | Not verified; no device connected |
| Cloud deployment | Not performed; project not linked |
| `test/features/sync_settings_test.dart` | Passed standalone and in full suite; explicit empty Supabase config, bounded settling, and Drift cleanup |

## Notes
- Public pull uses keyset pagination and preserves unsynced local edits.
- Admin mutations use `x-admin-session`; `Authorization` carries the anon key.
- Sync conflicts store the server snapshot and support reload/keep-local.
- WorkManager is best-effort and needs physical-device verification.
- Public RPC does not expose `version`; first edit after a cross-device pull may
  require conflict resolution.
