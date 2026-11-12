# Offline-first & Synchronization

## 1. Data flow

- App launch: initialize Drift → render local data immediately → start sync if connectivity available.
- All reads: Drift.
- All writes: local transaction + outbox atomically.
- Sync worker: claim queue item → send to Edge Function → handle response → mark success or conflict.
- Pull: fetch server changes since cursor/last sync and merge into local DB.
- UI observes Drift streams.

## 2. Outbox schema

Suggested columns:
- `operation_id UUID primary key`
- `entity_type TEXT`
- `entity_id UUID`
- `operation TEXT` (`create`, `update`, `archive`, `payment_create`, etc.)
- `payload JSON`
- `created_at`
- `retry_count`
- `status`
- `last_error_code`
- `next_retry_at`

## 3. Atomic local write

For every mutation:
1. Validate locally.
2. Begin SQLite transaction.
3. Write/modify entity.
4. Insert outbox operation with stable operation_id.
5. Commit.
6. UI immediately reflects local state.
7. Sync later.

Do not create outbox item outside the entity transaction.

## 4. Sync order and dependencies

- Customer/group create before debt referencing them.
- Debt create/update before payment referencing it.
- Payments are append-only and idempotent.
- Archive operations should not erase referenced records.
- Queue can be ordered by dependency and created time.
- If dependency fails, dependent operation remains pending/blocked.

## 5. Idempotency

- Every mutation has stable `operation_id`.
- Server stores processed operation IDs or enforces unique payment operation_id.
- Retrying the same operation returns the prior result without duplicating effects.
- Client must not generate a new operation_id on retry.

## 6. Conflict strategy

- Every mutable entity has `version`.
- Update includes expected version.
- Server rejects stale version with conflict response.
- Client retains local and server snapshots; mark entity conflict.
- UI offers compare/reload/resolve action.
- Do not silently overwrite finance data.
- Payments never use last-write-wins.

## 7. Pull synchronization

- Use cursor or server timestamp with deterministic ordering.
- Handle pagination.
- Account for records updated during pagination.
- Apply remote changes in SQLite transaction.
- Do not overwrite unsynced local edits without conflict resolution.
- Maintain tombstones/archive markers for deletions.

## 8. Retry and background work

- Retry transient network/5xx with exponential backoff and jitter.
- Do not endlessly retry validation/authorization failures.
- WorkManager is best-effort; foreground sync must also exist.
- Connectivity events trigger sync attempt but actual request determines connectivity.
- Expose pending count and last successful sync time.

## 9. Offline admin behavior

- Local PIN unlock can allow editing cached data offline.
- Clearly label changes as pending sync.
- Server-side authorization is checked when syncing.
- If session expired, queue remains intact and user must re-authenticate online.
- Do not discard local operations after auth failure.
