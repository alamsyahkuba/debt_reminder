# Offline-first & Synchronization

> **Revisi 12 November 2026:** read-only device enrollment dihapus. Publik
> membaca data melalui RPC read-only tanpa login/enrollment. Admin mutation
> tetap melalui outbox dan Edge Functions.
>
> **Status Sprint 07:** public pull paginasi, outbox sync idempoten, retry,
> conflict resolution, foreground/connectivity/manual sync, dan WorkManager
> best-effort sudah diimplementasikan. Detail keputusan ada di D-019.

## 1. Data flow

- App launch: initialize Drift → render local data immediately → pull public
  data if online.
- All reads: Drift.
- Admin writes: local transaction + outbox atomically.
- Admin sync worker: claim queue item → send to Edge Function → handle response
  → mark success/conflict.
- Public pull: fetch public group/debt/payment data via anon RPC and merge into
  local DB.
- UI observes Drift streams.

## 2. Public pull path

- Tidak perlu login dan tidak perlu enrollment perangkat.
- Gunakan anon/publishable key hanya untuk RPC read-only.
- RPC mengembalikan field bisnis publik: group, hutang, pembayaran, derived
  totals/status.
- Public client tidak memiliki outbox dan tidak boleh memanggil mutation
  endpoint.
- Pull menggunakan cursor/pagination dan transaksi SQLite.
- Data cache tetap bisa dibaca jika public pull gagal/offline.
- Revocation/device token tidak relevan karena tidak ada device enrollment.

## 3. Outbox schema

Digunakan hanya oleh admin mutation:

- `operation_id UUID primary key`
- `entity_type TEXT`
- `entity_id UUID`
- `operation TEXT` (`create`, `update`, `archive`, `payment_create`, dll.)
- `payload JSON`
- `created_at`
- `retry_count`
- `status`
- `last_error_code`
- `next_retry_at`

## 4. Atomic local write

Untuk setiap mutation admin:

1. Validasi lokal.
2. Begin SQLite transaction.
3. Write/modify entity.
4. Insert outbox operation dengan stable operation_id.
5. Commit.
6. UI langsung mencerminkan state lokal.
7. Sync nanti.

Jangan membuat outbox item di luar transaksi entity.

## 5. Sync order and dependencies

- Group create sebelum debt yang mereferensikannya.
- Debt create/update sebelum payment yang mereferensikannya.
- Payments append-only dan idempotent.
- Archive tidak menghapus referenced records.
- Queue diurutkan berdasarkan dependency dan created time.
- Jika dependency gagal, dependent operation tetap pending/blocked.
- Tidak ada customer dependency.

## 6. Idempotency

- Setiap mutation admin memiliki stable `operation_id`.
- Server menyimpan processed operation IDs dan/atau unique payment operation_id.
- Retry mengembalikan hasil sebelumnya tanpa duplikasi.
- Client tidak boleh membuat operation_id baru saat retry.

## 7. Conflict strategy

- Setiap mutable entity memiliki `version`.
- Update menyertakan expected version.
- Server menolak stale version dengan conflict response.
- Client menyimpan local dan server snapshot; mark entity conflict.
- UI menawarkan compare/reload/resolve.
- Jangan menimpa finance data diam-diam.
- Payments tidak pernah last-write-wins.

## 8. Pull synchronization

- Cursor/server timestamp dengan urutan deterministik.
- Handle pagination.
- Handle record yang berubah selama pagination.
- Apply remote changes dalam transaksi SQLite.
- Jangan menimpa unsynced local edits tanpa conflict resolution.
- Maintain archive/tombstone markers.
- Hard delete di server dideteksi melalui full-pull reconciliation (startup maksimal
  sekali per 24 jam dan manual sync); baris `synced` yang hilang dihapus, baris
  `pending`/`conflict` dipertahankan.
- Public pull tidak boleh mengubah outbox admin.

## 9. Retry and background work

- Retry transient network/5xx dengan exponential backoff + jitter.
- Jangan retry validation/authorization failure tanpa akhir.
- WorkManager best-effort; foreground sync wajib ada.
- Connectivity event memicu percobaan sync; hasil request tetap penentu.
- Tampilkan pending count dan last successful sync.

## 10. Offline admin behavior

- Offline local-only unlock belum tersedia; PIN diverifikasi server saat online.
- Setelah sesi valid, edit offline diizinkan dan ditandai pending sync.
- Server-side authorization diperiksa saat sync.
- Jika sesi expired, outbox tetap utuh dan admin diminta autentikasi online.
- Jangan membuang local operations setelah auth failure.

## 11. Public read behavior

- Publik selalu read-only.
- Public pull tidak membuat operasi tulis.
- Jika RPC publik gagal, tampilkan status offline/error dan tetap baca cache.
- Data bisnis yang tampil adalah data cache terakhir yang berhasil dipull.

## 12. Implementasi Sprint 07

- Pull publik memakai `public_*_page` dengan cursor keyset dan limit 1–500.
- `sync_queue.status`: `pending`, `processing`, `conflict`, `failed`.
- `sync_queue.conflict_data` menyimpan snapshot/versi server untuk resolusi.
- Worker mengurutkan group create/update/archive → debt → payment → group delete.
- Backoff eksponensial + jitter untuk network/5xx; auth failure berhenti tanpa
  membuang queue; validation failure ditandai gagal.
- Settings menampilkan pending/conflict/failed, timestamp terakhir, error, manual
  sync, dan aksi reload/keep-local.
- Foreground sync dipicu start/resume/connectivity; WorkManager periodik 15
  menit bersifat best-effort dan belum diverifikasi di perangkat fisik.
- Public RPC tidak mengekspos `version`; konflik pertama setelah pull dari
  perangkat lain diselesaikan lewat UI.

## 13. Keputusan Sprint 09

- Offline-first admin CRUD tetap dipertahankan; bukan online-only.
- Hard delete debt hanya jika belum ada payment; payment tetap append-only.
- Full-pull reconciliation menangani baris yang sudah dihapus server.
- Backup/export JSON tidak disinkronkan; restore-merge hanya menambahkan data
  yang belum ada dan tidak menimpa cloud secara otomatis.
- Tidak ada app lock/SQLite encryption atau PIN recovery UI di v1.
