# Supabase — Debt Reminder

Folder ini berisi schema PostgreSQL, RLS, idempotency helpers, dan Edge Function
shared utilities untuk aplikasi Catatan Hutang.

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

## Security model — Option A+

Keputusan owner: **tidak ada public read**, tetapi perangkat read-only yang
di-enroll admin boleh menarik data terbaru menggunakan token perangkat.

- RLS aktif pada semua tabel bisnis.
- Tidak ada policy untuk `anon` atau `authenticated`.
- `anon` dan `authenticated` tidak memiliki `USAGE` pada schema `public`.
- Tidak ada `SELECT`/`INSERT`/`UPDATE`/`DELETE` grant untuk kedua role itu.
- Tidak ada public view atau public RPC.
- `service_role` hanya digunakan di Edge Functions setelah admin session atau
  device token diverifikasi. Key ini tidak boleh masuk Flutter.
- `api.auto_expose_new_tables = false` agar tabel baru tidak otomatis terekspos.

Perangkat read-only:

- Admin membuat enrollment sekali pakai; perangkat menerima token opaque hanya
  sekali.
- Server menyimpan SHA-256 token di `read_devices`, bukan token asli.
- Setiap pull memeriksa hash, expiry, dan `revoked_at`.
- Token hanya boleh memanggil endpoint pull; tidak ada mutation.
- Admin dapat mencabut perangkat kapan saja.
- Field yang terlihat: nama, telepon, catatan, hutang, group, dan histori
  pembayaran. Field admin/audit/registry tetap tertutup.

Menambahkan public read anon nanti memerlukan keputusan owner baru dan migration
baru yang eksplisit. Jangan hanya menambah policy `anon`.

## Schema

| Tabel | Kegunaan |
|---|---|
| `customers` | Pelanggan pemilik hutang |
| `debt_groups` | Group hutang flat, tanpa `parent_id` |
| `debts` | Hutang, `group_id` nullable untuk Unassigned |
| `payments` | Pembayaran append-only dengan `operation_id` unik |
| `admin_settings` | Satu baris PIN hash dan metadata rate limit |
| `audit_logs` | Audit append-only, metadata allowlisted |
| `admin_sessions` | Sesi admin, menyimpan SHA-256 token |
| `operation_registry` | Registry idempotensi server-side |
| `read_devices` | Perangkat read-only ter-enroll, menyimpan SHA-256 token |

Aturan penting:

- Nominal uang memakai `bigint` integer rupiah, bukan floating point.
- `customers`, `debt_groups`, dan `debts` memiliki `version`; trigger menaikkan
  `version` dan `updated_at` pada setiap update.
- `payments` dan `audit_logs` menolak UPDATE/DELETE melalui trigger.
- `payments.debt_id` dan `debts.customer_id` memakai `ON DELETE RESTRICT`.
- `debts.group_id` memakai `ON DELETE SET NULL`; menghapus group memindahkan
  hutang menjadi Unassigned.
- `debt_groups.icon` memakai allowlist key, bukan kode widget arbitrary.
- `debts.principal_amount` dan `payments.amount` dibatasi ke safe integer JS.

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

- `auth.ts` — verifikasi JWT HS256 admin, umur token maksimal 15 menit,
  pengecekan sesi aktif + device binding, dan SHA-256 token hash.
- `device_auth.ts` — token opaque perangkat read-only, hash SHA-256, cek
  expiry/revocation, dan `last_seen_at`.
- `validation.ts` — validasi UUID, nominal rupiah, versi, tanggal, timestamp,
  allowlist field, dan ukuran JSON body.
- `idempotency.ts` — wrapper RPC claim/complete/fail dan canonical payload hash.
- `http.ts` — response JSON dan pemetaan error yang tidak membocorkan detail
  internal.

Token admin (diimplementasikan pada Sprint 06):

- `iss = debt-reminder`
- `aud = debt-reminder-admin`
- `role = admin`
- claim `session_id`, `device_id`, `iat`, `exp`
- ditandatangani `ADMIN_SESSION_JWT_SECRET` (minimal 32 karakter)
- token disimpan di client secure storage; server hanya menyimpan hash.

Token perangkat read-only (diimplementasikan pada Sprint 06–07):

- Opaque token berprefix `dr_dev_`, 32 byte acak.
- Hanya hash SHA-256 yang disimpan di `read_devices.token_hash`.
- Wajib memiliki `expires_at`; admin dapat mengisi `revoked_at`.
- Hanya valid untuk endpoint pull read-only.
- Jangan pernah memakai token ini untuk mutation atau mencampurnya dengan token
  admin.

Salin `supabase/functions/.env.example` menjadi
`supabase/functions/.env` untuk development lokal. Jangan commit nilai secret.

Test helper:

```bash
cd supabase/functions
deno fmt --check
deno check _shared/*.ts
deno lint
deno test
```

## Migration dan deployment

Migration ada di `supabase/migrations/` dan harus diterapkan berurutan.
Jangan mengedit migration yang sudah dipakai di environment bersama; buat
migration baru.

Untuk project cloud, setelah owner menyiapkan project dan kredensial:

```bash
npx --yes supabase@3.1.0 link --project-ref <project-ref>
npx --yes supabase@3.1.0 db push
```

Perintah cloud tidak dijalankan pada Sprint 01. Review RLS dan backup sebelum
`db push` ke production.

## Out of scope Sprint 01

- PIN verification dan session issuance (Sprint 06).
- Sync mutation endpoints (Sprint 07).
- Public read view/RPC (tidak dipakai pada v1).
- Seed/demo data (Sprint 02).
