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
- **Status:** Disetujui owner
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
- **Status:** Disetujui owner; fondasi schema/helper di Sprint 01, UI/endpoint di
  Sprint 06–07
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
