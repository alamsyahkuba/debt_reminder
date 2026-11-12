# Technical Decisions

Catatan keputusan teknis yang dibuat selama implementasi. Keputusan produk atau
keamanan yang berdampak luas tetap memerlukan persetujuan owner.

## D-001 — Konfigurasi environment melalui `--dart-define`

- **Tanggal:** 12 November 2026
- **Status:** Diadopsi untuk Sprint 00
- **Konteks:** Aplikasi membutuhkan konfigurasi Supabase tanpa membundel file
  rahasia ke dalam artefak Flutter.
- **Opsi:**
  1. `flutter_dotenv` dengan asset `.env`.
  2. `String.fromEnvironment`/`--dart-define`.
  3. Remote configuration.
- **Keputusan:** Gunakan `--dart-define` dan `--dart-define-from-file` dengan
  `config/app_config.example.json` sebagai contoh. File konfigurasi lokal
  di-ignore Git.
- **Konsekuensi:**
  - Perintah build/run harus menyertakan define saat konfigurasi diperlukan.
  - Test dan build tanpa define tetap berjalan.
  - Hanya URL dan anon/publishable key yang boleh berada di client;
    `service_role` tetap hanya di secret server.

## D-002 — Shell navigasi tunggal dengan GoRouter

- **Tanggal:** 12 November 2026
- **Status:** Diadopsi untuk Sprint 00
- **Konteks:** Drawer harus konsisten di seluruh halaman utama dan nantinya
  mendukung detail route.
- **Keputusan:** Gunakan satu `ShellRoute` yang membungkus placeholder screen.
  Judul AppBar dan item drawer dipetakan dari daftar `AppDestination`.
- **Konsekuensi:**
  - Detail screen dapat ditambahkan sebagai nested route tanpa menggandakan
    shell/drawer.
  - Guard admin dan status sesi akan ditambahkan pada Sprint 06, bukan melalui
    flag client.

## D-003 — Dependency fondasi dibatasi pada kebutuhan Sprint 00

- **Tanggal:** 12 November 2026
- **Status:** Diadopsi untuk Sprint 00
- **Konteks:** Proyek perlu menghindari dependency dan abstraksi yang belum
  dipakai.
- **Keputusan:** Sprint 00 hanya menambahkan `flutter_riverpod`, `go_router`,
  `intl`, dan `flutter_localizations`. Drift, Supabase, notifikasi, secure
  storage, connectivity, dan WorkManager ditambahkan pada sprint terkait.
- **Konsekuensi:** Tidak ada kode database, network, atau autentikasi pada
  fondasi ini.

## D-004 — Tidak ada public read pada v1 (Option A)

- **Tanggal:** 12 November 2026
- **Status:** Digantikan oleh D-013 (12 November 2026)
- **Konteks:** Aplikasi tidak memiliki login user biasa dan memakai shared
  database. `anon` key ikut dibundel di APK, sehingga public read berarti data
  dapat dibaca siapa pun yang mengekstrak key tersebut.
- **Opsi:**
  1. Tidak ada public read; hanya admin session.
  2. Public RPC dengan field minimal.
- **Keputusan:** Option A. Tidak ada public view/RPC, tidak ada policy
  anon/authenticated, dan kedua role kehilangan `USAGE` schema `public` serta
  seluruh grant tabel. Akses cloud melalui Edge Function dengan verifikasi
  sesi admin atau token perangkat read-only terdaftar (D-008), menggunakan
  service role di server.
- **Konsekuensi:**
  - Tidak ada akses anon ke data bisnis.
  - Perangkat non-admin harus di-enroll admin untuk menarik data cloud; lihat
    D-008. Data yang sudah tersinkron tetap dapat dibaca dari cache lokal.
  - Menambahkan public read nanti memerlukan persetujuan owner baru dan
    migration eksplisit.
  - `service_role` tidak boleh berada di Flutter atau artefak client.

> **Digantikan 12 November 2026:** owner mengubah keputusan menjadi public read
> seluruh field bisnis. Lihat D-013 dan D-014.

## D-005 — RLS deny-all dan explicit service-role grants

- **Tanggal:** 12 November 2026
- **Status:** Diadopsi untuk Sprint 01
- **Konteks:** Supabase default dapat memberi grant tabel baru ke role API.
- **Keputusan:**
  - RLS aktif pada semua tabel bisnis dan tabel internal.
  - `api.auto_expose_new_tables = false` pada konfigurasi lokal.
  - Default privileges untuk `anon`/`authenticated` dicabut.
  - Hanya `service_role` yang mendapat grant eksplisit.
  - `payments` dan `audit_logs` append-only melalui trigger database.
- **Konsekuensi:** Tabel baru pada migration berikutnya harus diberi grant
  eksplisit ke `service_role`; tidak ada akses anon secara default.

> **Direvisi 12 November 2026:** RLS tetap aktif pada base table, tetapi anon
> kini boleh execute RPC public read-only. Lihat D-013/D-014.

## D-006 — Kontrak sesi admin server-side

- **Tanggal:** 12 November 2026
- **Status:** Fondasi Sprint 01; issuance di Sprint 06
- **Konteks:** Token admin harus singkat, dapat dicabut, dan tidak dapat
  dipalsukan client.
- **Keputusan:**
  - JWT HS256 dengan `ADMIN_SESSION_JWT_SECRET` minimal 32 karakter.
  - `iss = debt-reminder`, `aud = debt-reminder-admin`, `role = admin`.
  - Token berlaku maksimal 15 menit dan memuat `session_id`/`device_id`.
  - Tabel `admin_sessions` menyimpan SHA-256 token, bukan token asli.
  - Setiap request memeriksa sesi aktif, `revoked_at`, dan kecocokan
    `device_id`.
- **Konsekuensi:** Secret hanya ada di Edge Function environment. Logout/lock
  di client harus menghapus token; pencabutan server-side menonaktifkan sesi.

## D-007 — Idempotency berbasis registry dan payload hash

- **Tanggal:** 12 November 2026
- **Status:** Diadopsi untuk Sprint 01
- **Konteks:** Retry jaringan tidak boleh menduplikasi pembayaran atau mutasi
  lain, dan server perlu membedakan retry sah dari reuse operation ID.
- **Keputusan:**
  - `operation_registry.operation_id` adalah primary key.
  - Payload asli tidak disimpan; hanya SHA-256 hash yang distabilkan.
  - `begin_operation`, `complete_operation`, dan `fail_operation` atomik.
  - `payments.operation_id` tetap unik sebagai perlindungan kedua.
- **Konsekuensi:** Client tidak boleh membuat operation ID baru saat retry.
  Payload berbeda dengan operation ID yang sama ditolak sebagai konflik.

## D-008 — Read-only device enrollment (Option A+)

- **Tanggal:** 12 November 2026
- **Status:** Dicabut oleh D-014 (12 November 2026)
- **Konteks:** Option A murni mengharuskan setiap perangkat memiliki sesi admin
  untuk menarik data cloud. Owner membutuhkan perangkat read-only yang bisa
  mengambil data terbaru tanpa menjadikan perangkat itu admin.
- **Keputusan:**
  - Admin mendaftarkan perangkat read-only dari sesi admin.
  - Perangkat menerima token opaque sekali pakai saat enrollment; server hanya
    menyimpan SHA-256 token di `read_devices`.
  - Token dapat dicabut dan wajib memiliki `expires_at`.
  - Perangkat read-only hanya boleh memakai endpoint pull; tidak ada mutation.
  - Anon/authenticated tetap tanpa akses; RLS tetap deny-all.
  - Field yang boleh dilihat perangkat terdaftar: nama pelanggan, nomor
    telepon, catatan pelanggan/hutang/pembayaran, data hutang/group, serta
    agregat dan histori pembayaran. Data admin/audit/operation registry tetap
    tertutup.
- **Konsekuensi:**
  - Ini bukan public read; perangkat harus di-enroll dan token harus valid.
  - Nomor telepon dan catatan kini termasuk data yang terlihat oleh perangkat
    terdaftar, sesuai pilihan owner.
  - Enrollment/revocation UI dan endpoint pull akan diimplementasikan pada
    Sprint 06/07.
  - Token yang bocor dapat dicabut admin; durasi expiry harus ditetapkan pada
    implementasi enrollment.

> **Dicabut 12 November 2026:** publik membaca langsung melalui RPC read-only;
> `read_devices`, device token, dan enrollment dihapus. Lihat D-013/D-014.

## D-009 — Local-first Drift schema dan atomic outbox

- **Tanggal:** 12 November 2026
- **Status:** Direvisi oleh D-015 (12 November 2026)
- **Konteks:** UI harus membaca dari SQLite, mutasi harus tetap aman saat
  offline, dan retry sync tidak boleh kehilangan operasi.
- **Keputusan:**
  - Drift schema versi 1 mencerminkan `customers`, `debt_groups`, `debts`, dan
    `payments`, ditambah `sync_queue` dan `sync_metadata`.
  - Entity mutable membawa `version`, `sync_state`, dan `server_updated_at`.
  - Setiap mutasi repository berjalan dalam satu transaksi SQLite bersama
    outbox entry dengan `operation_id` stabil.
  - Update memakai companion Drift agar kolom nullable bisa dikosongkan secara
    eksplisit; `insertOnConflictUpdate` dengan data class saja tidak cukup.
  - Pembayaran append-only, termasuk trigger SQLite yang menolak UPDATE/DELETE.
  - `onUpgrade` sengaja gagal sampai migration eksplisit ditambahkan; schema
    versi 1 tidak memiliki jalur upgrade.
- **Konsekuensi:**
  - UI tidak boleh menulis langsung ke Drift; gunakan repository.
  - Perubahan schema berikutnya wajib menaikkan `schemaVersion`, menambahkan
    migration, dan test migration.
  - SQLite lokal belum dienkripsi; keputusan app lock/encryption menunggu owner.

> **Direvisi 12 November 2026:** schema lokal di-reset tanpa customers dan
> `read_devices`. Lihat D-015.

## D-010 — Demo seed opt-in untuk development

- **Tanggal:** 12 November 2026
- **Status:** Diadopsi untuk Sprint 02
- **Konteks:** Developer membutuhkan data contoh tanpa mengotori database
  production atau membuat outbox palsu.
- **Keputusan:** Seed demo hanya berjalan jika `APP_ENV=development` dan
  `SEED_DEMO_DATA=true`. Semua baris demo ditandai `synced` dan tidak membuat
  outbox. Seed tidak berjalan jika database sudah berisi data.
- **Konsekuensi:** Jangan aktifkan flag ini sebelum menghubungkan aplikasi ke
  cloud nyata. Hapus database lokal jika ingin mengulang seed.

## D-011 — Kebijakan delete group

- **Tanggal:** 12 November 2026
- **Status:** Diadopsi untuk Sprint 03; customer portion dihapus oleh D-014
- **Konteks:** Group perlu bisa dihapus tanpa kehilangan histori hutang.
- **Keputusan:**
  - Delete group berjalan dalam satu transaksi: semua hutang di group
    dipindahkan ke Unassigned, versi/sync state-nya diperbarui, outbox update
    hutang dibuat lebih dulu, lalu group dihapus dan outbox delete group dibuat.
  - Hutang, pembayaran, dan histori tidak pernah dihapus oleh delete group.
  - Ringkasan group dihitung dari hutang dan pembayaran, bukan counter manual.
- **Konsekuensi:** Delete group menghasilkan beberapa operasi sync dan harus
  diurutkan oleh sync worker pada Sprint 07.

## D-012 — Admin PIN gate ditunda sampai Sprint 06

- **Tanggal:** 12 November 2026
- **Status:** Urutan implementasi Sprint 03–05
- **Konteks:** Group/debt/payment management dibangun sebelum PIN/session admin.
  Sprint 03–05 belum memiliki jalur mutasi cloud.
- **Keputusan:** Aksi pengelolaan lokal pada Sprint 03–05 dapat diakses tanpa
  PIN. Sprint 06 wajib memasang route guard dan admin session sebelum sync
  mutation diaktifkan. Server tetap menjadi otoritas untuk semua mutasi cloud.
- **Konsekuensi:** Build lokal saat ini bukan release-ready; jangan
  mendistribusikan APK sebelum Sprint 06 selesai. Tidak ada klaim bahwa UI guard
  adalah otorisasi server.

## D-013 — Public read seluruh data bisnis

- **Tanggal:** 12 November 2026
- **Status:** Disetujui owner; public RPC implemented in Sprint 01R; public
  Flutter read-only mode/pull pending Sprint 07
- **Konteks:** Owner memutuskan aplikasi hanya memiliki owner/admin dan publik.
  Publik harus dapat melihat data tanpa login.
- **Keputusan:**
  - Publik dapat membaca seluruh field bisnis: group, hutang, pembayaran,
    catatan, nominal, tanggal, status arsip, dan status turunan.
  - Public read hanya melalui RPC read-only dengan field allowlist.
  - Base table tidak memberikan SELECT langsung ke anon.
  - Anon tidak memiliki INSERT/UPDATE/DELETE.
  - Data admin, audit, sesi, operation registry, PIN, token, dan sync metadata
    tetap privat.
- **Konsekuensi:**
  - Siapa pun dengan anon/publishable key dapat membaca data bisnis.
  - “Semua data publik” adalah tradeoff privasi yang disetujui owner.
  - Public UI harus read-only dan tidak membuat outbox.

## D-014 — Hapus customer dan read-only device enrollment

- **Tanggal:** 12 November 2026
- **Status:** Disetujui owner; cloud removal done in Sprint 01R and local
  cleanup done in Sprint 02R/03R
- **Konteks:** Owner menyederhanakan produk menjadi group, hutang, dan
  pembayaran, serta memilih public read langsung.
- **Keputusan:**
  - Hapus tabel/entity/DAO/repository/UI/test `customers`.
  - Hapus `debts.customer_id`.
  - Tidak ada `borrower_name` terpisah; identitas ditulis di title/notes.
  - Hapus `read_devices`, device token, enrollment UI, dan helper device auth.
  - Group tetap ada.
- **Konsekuensi:** Implementasi Sprint 01–03 harus dirework. Tidak ada migrasi
  data pelanggan; database di-reset karena belum release.

## D-015 — Reset database dan local schema v2

- **Tanggal:** 12 November 2026
- **Status:** Disetujui owner; cloud reset and local SQLite reset done in
  Sprint 01R/02R
- **Konteks:** Schema lama memuat customers/read_devices dan tidak sesuai
  produk baru. Belum ada data produksi.
- **Keputusan:**
  - Reset database cloud/local daripada memigrasikan data pelanggan.
  - Cloud migration baru menghapus customers/read_devices/customer_id dan
    menambahkan public RPC read-only.
  - Drift schema dinaikkan/di-reset tanpa customers dan read_devices.
  - Public mode tidak memiliki outbox; hanya admin mutation yang memiliki
    outbox.
- **Konsekuensi:** Data lama akan hilang; ini disetujui karena aplikasi belum
  release. Semua test dan dokumentasi harus disesuaikan.

## D-016 — Status hutang diturunkan dari pembayaran dan due date

- **Tanggal:** 13 November 2026
- **Status:** Diadopsi untuk Sprint 04
- **Konteks:** Status hutang tidak boleh menjadi sumber kebenaran terpisah yang
  bisa tidak sinkron dengan pembayaran.
- **Keputusan:**
  - `paidAmount` adalah jumlah pembayaran per hutang.
  - `outstandingAmount` = max(principal - paidAmount, 0).
  - Status:
    - `paid` jika paidAmount >= principal.
    - `overdue` jika belum lunas dan due date sebelum hari ini.
    - `partial` jika paidAmount > 0.
    - `unpaid` jika belum ada pembayaran.
  - UI menggunakan `DebtOverview` yang dihitung dari entity debt + total
    pembayaran, bukan kolom status mutable.
- **Konsekuensi:** Daftar/detail hutang dan dashboard harus memakai perhitungan
  yang sama; payment history tetap append-only.
