# Sprint 07 — Offline Sync

## Goal
Synchronize admin mutations through the outbox and pull public data through the
read-only RPC.

## Tasks
- [ ] Implement admin sync service and queue claiming.
- [ ] Implement Edge Function batch sync or entity mutation endpoints.
- [ ] Enforce dependency ordering: group → debt → payment.
- [ ] Implement stable idempotency.
- [ ] Implement retry/backoff.
- [ ] Implement pull cursor and pagination.
- [ ] Implement version conflict detection.
- [ ] Implement conflict state and resolution UI.
- [ ] Implement connectivity-triggered sync.
- [ ] Implement foreground sync and best-effort WorkManager sync.
- [ ] Add sync status UI and manual sync.
- [ ] Implement public pull via anon read-only RPC.
- [ ] Ensure public pull never creates outbox entries or calls mutation endpoints.
- [ ] Test force-close/restart with pending queue.
- [ ] Test duplicate retry and stale-version conflict.
- [ ] Test public pull, anon mutation denial, and pagination.

## Acceptance criteria
- Offline admin mutations survive restart.
- Sync sends each logical operation once.
- Duplicate retries do not duplicate payments.
- Stale updates produce conflict, not silent overwrite.
- Pending operations remain intact after authorization/network errors.
- Local data remains usable while sync is failing.
- Public devices pull approved business data without login or enrollment.
- Public pull cannot mutate data.
- No customer dependency exists in sync ordering.
