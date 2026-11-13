# Supabase — Debt Reminder

Folder ini berisi schema PostgreSQL, RLS, idempotency helpers, public read RPCs,
dan Edge Function shared utilities untuk aplikasi Catatan Hutang.

> **Status implementasi:** cloud schema, public read + pagination RPC, local
> Flutter/Drift customer cleanup, payment/dashboard, admin PIN/session, dan
> admin sync sudah selesai. Reminder lokal Sprint 08 tidak menambah tabel atau
> endpoint server. Migration lama customers/read_devices dihapus dan local
> Supabase sudah di-reset. Cloud project belum di-push. WorkManager/background
> sync dan pengiriman notifikasi belum diverifikasi di perangkat fisik.

## Prasyarat

- Docker.
- Supabase CLI 3.1.0 (dijalankan lewat `npx` pada contoh di bawah).
- Deno 2 untuk test helper Edge Function.

## Menjalankan database lokal

```bash
npx --yes supabase@3.1.0 db start
npx --yes supabase@3.1.0 db reset
npx --yes supabase@3.1.0 test db
npx --yes supabase@3.1.0 db lint
```

`db start` menjalankan PostgreSQL lokal di `127.0.0.1:54322`. `db reset`
membuat ulang database dari seluruh migration dan seed (seed saat ini
dinonaktifkan). `test db` menjalankan pgTAP tests di `supabase/tests/`.

Untuk menghentikan stack lokal:

```bash
npx --yes supabase@3.1.0 stop --no-backup
```

## Security model target

Keputusan owner: **semua field bisnis publik, read-only**.

- RLS aktif pada semua tabel.
- Publik hanya boleh execute RPC public read-only.
- Anon tidak mendapat SELECT langsung pada base table.
- Anon tidak memiliki INSERT/UPDATE/DELETE.
- Semua mutation admin melalui Edge Function dengan sesi admin server-side.
- `service_role` hanya digunakan di Edge Function setelah admin session
  diverifikasi. Key ini tidak boleh masuk Flutter.
- Data admin, audit, sesi, PIN, token, operation registry, dan sync metadata
  tetap privat.
- `api.auto_expose_new_tables = false` agar tabel baru tidak otomatis terekspos.
- Tidak ada `customers`, `read_devices`, atau device enrollment.

## Public read RPCs

RPC publik harus read-only, memakai `security definer` dengan `search_path`
tetap, dan hanya memberikan `execute` kepada `anon`.

### `public_debt_groups`
- id
- name
- description
- color
- icon
- sort_order
- is_archived
- created_at
- updated_at

### `public_debts`
- id
- group_id
- group_name
- title
- principal_amount
- due_date
- notes
- is_archived
- created_at
- updated_at
- paid_amount
- outstanding_amount
- status

### `public_payments`
- id
- debt_id
- amount
- paid_at
- notes
- created_at

### Paginated pull RPCs
- `public_debt_groups_page(p_after_updated_at, p_after_id, p_limit)`
- `public_debts_page(p_after_updated_at, p_after_id, p_limit)`
- `public_payments_page(p_after_created_at, p_after_id, p_limit)`

Keyset pagination memakai `(updated_at, id)` untuk group/debt dan
`(created_at, id)` untuk payment. `p_limit` dibatasi 1–500. Cursor harus
dikirim lengkap atau tidak sama sekali.

Aturan:

- Semua field bisnis boleh dibaca publik.
- `version`, `operation_id`, sync metadata, admin/audit/session fields tidak
  boleh dikembalikan.
- RPC tidak boleh melakukan mutation.
- Archived records dapat dibaca; UI default menyembunyikan arsip dan
  menyediakan filter histori.

## Schema target

| Tabel | Kegunaan |
|---|---|
| `debt_groups` | Group hutang flat, tanpa `parent_id` |
| `debts` | Hutang, `group_id` nullable untuk Unassigned |
| `payments` | Pembayaran append-only dengan `operation_id` unik |
| `admin_settings` | Satu baris PIN hash dan metadata rate limit |
| `audit_logs` | Audit append-only, metadata allowlisted |
| `admin_sessions` | Sesi admin, menyimpan SHA-256 token |
| `operation_registry` | Registry idempotensi server-side |

Aturan penting:

- Nominal uang memakai `bigint` integer rupiah, bukan floating point.
- `debt_groups` dan `debts` memiliki `version`; trigger menaikkan `version` dan
  `updated_at` pada setiap update.
- `payments` dan `audit_logs` menolak UPDATE/DELETE melalui trigger.
- `payments.debt_id` memakai `ON DELETE RESTRICT`.
- `debts.group_id` memakai `ON DELETE SET NULL`; menghapus group memindahkan
  hutang menjadi Unassigned.
- `debt_groups.icon` memakai allowlist key, bukan kode widget arbitrary.
- `debts.principal_amount` dan `payments.amount` dibatasi ke safe integer JS.
- Tidak ada `customer_id`, `customers`, atau `read_devices`.

## Idempotency

Alur server:

1. Edge Function menghitung hash payload yang stabil.
2. `begin_operation(operation_id, operation, entity_type, entity_id, payload_hash)`
   mengklaim operasi secara atomik.
3. Jika operasi sudah `succeeded`/`failed`, Edge Function mengembalikan response
   tersimpan tanpa mengulang efek samping.
4. Jika payload berbeda untuk `operation_id` yang sama, server menolak.
5. `complete_operation` atau `fail_operation` menyimpan hasil akhir.

`operation_registry` tidak menyimpan payload asli, hanya SHA-256 hash.
`payments.operation_id` juga unik sebagai perlindungan kedua.

## Edge Function shared helpers

Lokasi: `supabase/functions/_shared/`.

Target:

- `auth.ts` — verifikasi JWT HS256 admin, umur token maksimal 15 menit,
  pengecekan sesi aktif + device binding, dan SHA-256 token hash.
- `validation.ts` — validasi UUID, nominal rupiah, versi, tanggal, timestamp,
  allowlist field, dan ukuran JSON body.
- `idempotency.ts` — wrapper RPC claim/complete/fail dan canonical payload hash.
- `http.ts` — response JSON dan pemetaan error yang tidak membocorkan detail
  internal.

Device authentication/read-only device token sudah dihapus. Public read tidak
memerlukan enrollment.

Token admin (diimplementasikan pada Sprint 06):

- `iss = debt-reminder`
- `aud = debt-reminder-admin`
- `role = admin`
- claim `session_id`, `device_id`, `iat`, `exp`
- ditandatangani `ADMIN_SESSION_JWT_SECRET` (minimal 32 karakter)
- token disimpan di client secure storage; server hanya menyimpan hash.
- Token dikirim melalui header `x-admin-session`, bukan `Authorization`.
  `Authorization: Bearer <anon-key>` tetap dipakai agar gateway Supabase dapat
  memverifikasi request. Ini menghindari konflik verifikasi JWT gateway.

Salin `supabase/functions/.env.example` menjadi `supabase/functions/.env` untuk
development lokal. Jangan commit nilai secret.

## Admin PIN Edge Function

Nama function: `admin-pin` (`supabase/functions/admin-pin/`).

Request `POST` dengan JSON:

```json
{"action":"verify","pin":"123456","device_id":"opaque-device-id"}
{"action":"change","current_pin":"123456","new_pin":"654321"}
{"action":"logout"}
```

Aturan:

- PIN numerik 6 digit.
- 5 percobaan gagal mengunci verifikasi 15 menit (dapat diatur lewat
  `ADMIN_PIN_MAX_ATTEMPTS` dan `ADMIN_PIN_LOCK_SECONDS`).
- Sesi admin berlaku 15 menit, disimpan sebagai SHA-256 token di
  `admin_sessions`, dan dapat dicabut.
- `change` dan `logout` wajib menyertakan `x-admin-session`.
- PIN di-hash dengan PBKDF2-HMAC-SHA256, salt acak, dan `ADMIN_PIN_PEPPER`.
- Bootstrap pertama memakai `ADMIN_INITIAL_PIN`; rate limit tetap berlaku karena
  `admin_settings` dibuat dalam keadaan `uninitialized`. Hapus secret bootstrap
  setelah PIN berhasil dibuat.
- Audit log mencatat verifikasi, kegagalan, perubahan PIN, dan logout tanpa
  menyimpan PIN/token.
- Response tidak pernah mengembalikan PIN hash atau secret.

Menjalankan function lokal:

```bash
npx --yes supabase@3.1.0 functions serve admin-pin admin-sync --env-file supabase/functions/.env
```

## Admin Sync Edge Function

Nama function: `admin-sync` (`supabase/functions/admin-sync/`).

Request `POST` dengan header `x-admin-session`:

```json
{
  "operation_id": "uuid",
  "operation": "create|update|archive|delete|payment_create",
  "entity_type": "debt_group|debt|payment",
  "entity_id": "uuid",
  "payload": {}
}
```

Alur:

1. Validasi allowlist field dan tipe operasi.
2. Verifikasi sesi admin server-side.
3. Hash payload kanonik.
4. Panggil `admin_apply_mutation` dengan service role.
5. PostgreSQL melakukan idempotency registry, version check, mutasi, audit, dan
   menyimpan response dalam satu transaksi.
6. Replay mengembalikan response lama; stale version mengembalikan 409 beserta
   `server_version`, `server_updated_at`, dan `server_row`.

Urutan dependency dilakukan di client: group create/update/archive → debt →
payment → group delete.

Test helper:

```bash
cd supabase/functions
deno fmt --check
deno check _shared/*.ts admin-pin/*.ts admin-sync/*.ts
deno lint
deno test
```

Test mencakup public read/pagination, anon denial, idempotency, PIN hashing,
JWT signing/verification, rate limit, session lifecycle, invalid/expired token,
PIN change/logout, audit, payload validation, version conflict, dan replay.

## Migration, reset, dan deployment

Sprint 01R menggunakan reset, bukan migrasi data pelanggan:

- Baseline migration sudah diganti dengan schema tanpa customers/read_devices.
- Public read RPC dan RLS read-only sudah ditambahkan.
- Database lokal Supabase sudah di-reset dan test lulus.
- Cloud project belum di-reset/di-push; belum ada data produksi.

Setelah rework cloud selesai dan owner menyetujui:

```bash
npx --yes supabase@3.1.0 link --project-ref <project-ref>
npx --yes supabase@3.1.0 db push
npx --yes supabase@3.1.0 secrets set \
  ADMIN_SESSION_JWT_SECRET=<min-32-characters> \
  ADMIN_PIN_PEPPER=<min-32-characters> \
  ADMIN_INITIAL_PIN=<6-digit-bootstrap-pin>
npx --yes supabase@3.1.0 functions deploy admin-pin
npx --yes supabase@3.1.0 functions deploy admin-sync
```

Hapus `ADMIN_INITIAL_PIN` dari secrets setelah PIN pertama berhasil dibuat.

## Out of scope saat ini

- Perangkat read-only dan device enrollment (dihapus).
- Data pelanggan (dihapus).
- Seed/demo data produksi.
- Deployment cloud dan verifikasi perangkat fisik.
