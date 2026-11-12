# Sprint 07 — Offline Sync

## Goal
Synchronize local outbox and cloud changes safely.

## Tasks
- [ ] Implement sync service and queue claiming.
- [ ] Implement Edge Function batch sync or entity mutation endpoints.
- [ ] Enforce dependency ordering.
- [ ] Implement stable idempotency.
- [ ] Implement retry/backoff.
- [ ] Implement pull cursor and pagination.
- [ ] Implement version conflict detection.
- [ ] Implement conflict state and resolution UI.
- [ ] Implement connectivity-triggered sync.
- [ ] Implement foreground sync and best-effort WorkManager sync.
- [ ] Add sync status UI and manual sync.
- [ ] Implement read-only device pull endpoint using device token, with
      revocation/expiry checks and approved field allowlist.
- [ ] Ensure read-only pulls cannot enqueue or execute mutations.
- [ ] Test force-close/restart with pending queue.
- [ ] Test duplicate retry and stale-version conflict.
- [ ] Test revoked/expired read-only device, field filtering, and pagination.

## Acceptance criteria
- Offline mutations survive restart.
- Sync sends each logical operation once.
- Duplicate retries do not duplicate payments.
- Stale updates produce conflict, not silent overwrite.
- Pending operations remain intact after authorization/network errors.
- Local data remains usable while sync is failing.
- Enrolled read-only devices can pull approved fields (including phone/notes)
  without access to admin data.
- Revoked/expired device tokens cannot pull.
- Read-only pull cannot mutate data.
