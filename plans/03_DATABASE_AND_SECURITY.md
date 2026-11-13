# Database & Security

> **Revisi 12 November 2026:** plan ini menggantikan Option A/A+.
> Data pelanggan dan read-only device enrollment dihapus. Semua field bisnis
> dapat dibaca publik melalui RPC read-only. Database lama akan di-reset.

## 1. Cloud schema

### `debt_groups`
- `id uuid primary key`
- `name text not null`
- `description text null`
- `color text null` (hex token/string tervalidasi)
- `icon text null` (icon key dari allowlist, bukan arbitrary widget code)
- `sort_order integer not null default 0`
- `is_archived boolean not null default false`
- `created_at timestamptz not null`
- `updated_at timestamptz not null`
- `version bigint not null default 1`
- Tidak ada `parent_id`: group sederhana, tidak bertingkat.

### `debts`
- `id uuid primary key`
- `group_id uuid null references debt_groups(id) on delete set null`
- `title text not null`
- `principal_amount bigint not null check (principal_amount > 0)`
- `due_date date null`
- `notes text null`
- `is_archived boolean not null default false`
- `created_at timestamptz not null`
- `updated_at timestamptz not null`
- `version bigint not null default 1`

Tidak ada `customer_id` dan tidak ada tabel `customers`. Identitas peminjam,
bila diperlukan, ditulis di `title` atau `notes`.

Paid amount dihitung dari payments. Debt status diturunkan di query/domain,
bukan disimpan sebagai mutable status.

Hard delete debt hanya diizinkan jika belum memiliki payment. Debt yang sudah
memiliki payment hanya boleh diarsipkan; payment tidak pernah dihapus.

### `payments`
- `id uuid primary key`
- `debt_id uuid not null references debts(id)`
- `amount bigint not null check (amount > 0)`
- `paid_at timestamptz not null`
- `notes text null`
- `operation_id uuid not null unique`
- `created_at timestamptz not null`

Payments are append-only. Enforce no duplicate `operation_id`. Koreksi harus
berupa adjustment/reversal yang tercatat. Debt dengan payment tidak boleh
hard-delete.

### `admin_settings`
- Single logical row, fixed UUID.
- `pin_hash text not null`
- `pin_hash_algorithm text not null` (`uninitialized` sebelum PIN pertama dibuat,
  lalu `pbkdf2_sha256`)
- `updated_at timestamptz not null`
- Optional `pin_changed_at`, failed attempt metadata.

### `audit_logs`
- `id uuid primary key`
- `actor_type text`
- `action text`
- `entity_type text`
- `entity_id uuid null`
- `operation_id uuid null`
- `metadata jsonb` (allowlisted, no secrets)
- `created_at timestamptz`

### `admin_sessions`
- `id uuid primary key`
- `token_hash text not null unique` (SHA-256 hex)
- `device_id text not null`
- `issued_at timestamptz not null`
- `expires_at timestamptz not null`
- `revoked_at timestamptz null`
- `last_used_at timestamptz null`
- `created_at timestamptz not null`

### `operation_registry`
- `operation_id uuid primary key`
- `actor_type text not null`
- `operation text not null`
- `entity_type text not null`
- `entity_id uuid null`
- `payload_hash text not null` (SHA-256 hex; payload asli tidak disimpan)
- `status text not null` (`processing`, `succeeded`, `failed`)
- `response jsonb null`
- `error_code text null`
- `created_at`, `updated_at`, `completed_at timestamptz`

### Tabel yang dihapus
- `customers`
- `read_devices`
- `debts.customer_id`
- Semua helper/device-token terkait read-only enrollment.

## 2. Public read

Public read disetujui owner untuk seluruh **field bisnis**. Gunakan RPC
read-only, bukan grant SELECT ke tabel mentah.

### `public_debt_groups`
- id, name, description, color, icon, sort_order, is_archived, created_at,
  updated_at.

### `public_debts`
- id, group_id, group_name, title, principal_amount, due_date, notes,
  is_archived, created_at, updated_at, paid_amount, outstanding_amount, status.

### `public_payments`
- id, debt_id, amount, paid_at, notes, created_at.

Aturan:

- RPC menggunakan `security definer` dengan `search_path` tetap.
- `grant execute` hanya ke `anon`.
- RPC hanya SELECT; tidak ada mutation.
- Pull memakai RPC paginasi keyset:
  - `public_debt_groups_page(p_after_updated_at, p_after_id, p_limit)`
  - `public_debts_page(p_after_updated_at, p_after_id, p_limit)`
  - `public_payments_page(p_after_created_at, p_after_id, p_limit)`
- `p_limit` dibatasi 1–500; cursor harus lengkap atau kosong.
- Field internal tidak diekspos: `version`, `operation_id`, `sync_state`,
  `server_updated_at`, audit metadata, session/token.
- Base table RLS aktif; anon tidak mendapat grant langsung.
- Anon tidak memiliki INSERT/UPDATE/DELETE.
- Archived records dapat dibaca publik; UI default menyembunyikan arsip dan
  menyediakan filter histori.
- Hard delete menyebabkan baris hilang dari server; client menjalankan full-pull
  reconciliation saat startup (maksimal sekali per 24 jam) dan manual sync.
  Baris lokal `synced` yang tidak ada di server dihapus; `pending`/`conflict`
  dipertahankan.
- Admin tetap dapat membaca melalui sesi admin; mutation tetap lewat Edge
  Function.

## 3. Local schema

Target revisi: Drift schema baru setelah reset.

- `debt_groups`, `debts`, dan `payments` dengan field bisnis yang sama.
- `debts` tidak memiliki `customer_id`.
- Mutable entities membawa `version`, `sync_state` (`pending`, `synced`,
  `conflict`), dan `server_updated_at`.
- `payments.operation_id` unik dan append-only; trigger SQLite menolak
  UPDATE/DELETE.
- `sync_queue` untuk mutation admin.
- `sync_metadata` untuk cursor pull publik/admin.
- `sync_queue.conflict_data` menyimpan snapshot/versi server untuk resolusi.
- `local_settings` menyimpan preferensi reminder perangkat; tidak disinkronkan.
- Backup/export JSON hanya berisi field bisnis group/debt/payment; metadata
  internal, session, audit, `version`, dan `operation_id` tidak diekspor.
- `PRAGMA foreign_keys = ON`; group deletion set `debts.group_id` null.
- Public mode tidak membuat outbox.
- Schema lama (customers/read_devices) harus dihapus. Karena aplikasi belum
  release, reset database lokal dan cloud lebih disarankan daripada migrasi
  data.
- Demo seed development hanya berisi group, hutang, dan pembayaran.

## 4. Security model

### Public read
- Seluruh field bisnis publik melalui RPC read-only.
- Tidak ada anon SELECT ke tabel mentah.
- Tidak ada anon INSERT/UPDATE/DELETE.
- Tidak ada public view/RPC yang mengembalikan admin settings, audit logs,
  sessions, operation registry, PIN, token, atau metadata internal.
- RLS aktif pada semua tabel.
- Test anon read dan anon mutation denial.

### Admin mutation
- Admin mutations melalui Edge Functions.
- Verifikasi admin session/token server-side pada setiap mutation.
- Service role secret hanya di Edge Function environment.
- Validasi payload, IDs, amount, dates, relations, version, dan idempotency.
- Rate-limit PIN verification; constant-time comparison bila relevan.
- Jangan pernah mengembalikan PIN hash.
- Admin token short-lived, signed, revocable, dan bound ke device bila feasible.
- Token admin dikirim melalui header `x-admin-session`; header `Authorization`
  tetap dipakai untuk JWT Supabase/anon key di gateway.
- Client-side `isAdmin=true` bukan otorisasi.
- `admin_apply_mutation` melakukan idempotency, version check, mutasi, audit, dan
  response dalam satu transaksi service-role.

### PIN
- PIN low entropy; gunakan server-side pepper dan password hashing yang sesuai.
- Rate limit dan lockout.
- Tidak ada PIN recovery UI di v1; reset hanya melalui prosedur operator/
  server-side dan `ADMIN_INITIAL_PIN` hanya untuk bootstrap.
- Response tidak boleh membocorkan detail internal.
- Offline unlock hanya kenyamanan lokal; bukan otorisasi cloud.
- Saat reconnect, server tetap meminta sesi admin valid untuk mutation.

### Internal data
Tidak publik:
- `admin_settings`
- `admin_sessions`
- `audit_logs`
- `operation_registry`
- PIN/token material
- sync metadata internal

### Data privacy decision
Owner sudah memutuskan:
1. Semua data bisnis publik.
2. Data pelanggan tidak ada.
3. Public read hanya read-only melalui RPC.
4. Device-level app lock/local SQLite encryption tidak dipakai di v1 dan harus
   didokumentasikan sebagai keterbatasan.

## 5. RLS checklist

- Enable RLS pada semua tabel.
- Explicit policies only.
- Anon hanya boleh execute public read RPC.
- Tidak ada anon SELECT langsung ke base table.
- Tidak ada anon mutation.
- Tidak ada akses anon ke `admin_settings`, `admin_sessions`, `audit_logs`,
  `operation_registry`.
- Test dengan role anon dan authenticated.
- Verify service role tidak ada di Flutter.
- Verify public RPC tidak mengembalikan field internal.
- Verify `customer`/`read_devices` benar-benar tidak ada.

## 6. Reset dan rework

Karena data lama belum produksi:

- Ganti baseline migration dengan schema baru tanpa `customers`,
  `read_devices`, dan `debts.customer_id`.
- Migration lama yang memuat customer/device enrollment boleh dihapus dari repo
  karena proyek di-reset, bukan di-upgrade.
- Reset database lokal Supabase dan cloud project setelah owner menyetujui.
- Reset SQLite lokal; jangan mencoba migrasi data pelanggan.
- Hapus customer repository/entity/DAO/UI/test.
- Hapus device auth helper dan enrollment.
- Tambah public RPC, RLS read-only, dan test.

Jika di kemudian hari ada database yang tidak boleh di-reset, buat migration
drop/backfill terpisah; itu bukan jalur v1 saat ini.
