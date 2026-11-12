# Supabase — Debt Reminder

Folder ini berisi schema PostgreSQL, RLS, idempotency helpers, public read RPCs,
dan Edge Function shared utilities untuk aplikasi Catatan Hutang.

> **Status implementasi:** cloud schema, public read RPC, dan local Flutter/
> Drift customer cleanup sudah selesai. Migration lama customers/read_devices
> dihapus dan local Supabase sudah di-reset. Cloud project belum di-push.
> Public Flutter pull/read-only mode dijadwalkan Sprint 07.

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

Test device enrollment sudah dihapus. Test sekarang mencakup public read RPC,
anon denial, idempotency, dan admin/session foundation.

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
```

## Out of scope saat ini

- PIN verification dan session issuance (Sprint 06).
- Sync mutation endpoints (Sprint 07).
- Perangkat read-only dan device enrollment (dihapus).
- Data pelanggan (dihapus).
- Seed/demo data produksi.
- Public Flutter pull/read-only mode (Sprint 07).
