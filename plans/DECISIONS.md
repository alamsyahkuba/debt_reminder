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
  - SQLite lokal tidak dienkripsi di v1; app lock/encryption tidak dipakai dan
    keterbatasannya didokumentasikan (lihat D-023).

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

## D-017 — Pembayaran append-only, overpayment ditolak, dashboard turunan

- **Tanggal:** 13 November 2026
- **Status:** Diadopsi untuk Sprint 05
- **Konteks:** Pembayaran adalah histori finansial yang tidak boleh diedit atau
  dihapus diam-diam, dan dashboard tidak boleh menghitung angka dengan rumus
  berbeda dari daftar/detail hutang.
- **Keputusan:**
  - Form pembayaran meminta konfirmasi sebelum menyimpan.
  - Nominal pembayaran harus > 0 dan total pembayaran tidak boleh melebihi
    pokok hutang; repository menolak di dalam transaksi SQLite, bukan hanya di
    UI.
  - Setiap pembayaran menyimpan `operation_id` unik dan outbox entry dibuat
    dalam transaksi yang sama.
  - Dashboard memakai `DashboardSummary` yang diturunkan dari `DebtOverview`
    aktif, sehingga total pokok, dibayar, sisa, dan hitungan status konsisten
    dengan debt list.
  - Ringkasan group memakai `GroupSummary`; archived group tetap ditampilkan
    bila masih memiliki hutang aktif, dan hutang tanpa group ditampilkan
    sebagai Unassigned.
  - Jatuh tempo terdekat mencakup hutang overdue dan due date dalam 7 hari ke
    depan; hutang lunas tidak ditampilkan.
- **Konsekuensi:** Overpayment tidak dapat dipaksa dari UI atau repository.
  Perubahan kebijakan overpayment harus disetujui owner dan dilakukan di
  repository, test, dan dokumentasi sekaligus. Sync indicator belum menjadi
  bagian Sprint 05; indikator outbox menyusul di Sprint 07.

## D-018 — PIN admin, sesi server, dan header token admin

- **Tanggal:** 13 November 2026
- **Status:** Server session diadopsi untuk Sprint 06; offline local-only unlock
  masih menunggu konfirmasi owner.
- **Konteks:** PIN harus diverifikasi server agar client tidak dapat memberi
  dirinya sendiri akses admin. Gateway Supabase memverifikasi header
  `Authorization` sebagai JWT Supabase, sehingga token admin kustom tidak dapat
  memakai header tersebut.
- **Keputusan:**
  - PIN numerik 6 digit; 5 percobaan gagal mengunci verifikasi 15 menit.
  - Sesi admin berlaku 15 menit, dapat dicabut, dan dapat di-lock dari UI.
  - PIN di-hash dengan PBKDF2-HMAC-SHA256 (210.000 iterasi), salt acak, dan
    `ADMIN_PIN_PEPPER` server-side.
  - Token sesi adalah JWT HS256 yang ditandatangani
    `ADMIN_SESSION_JWT_SECRET`; server hanya menyimpan SHA-256 token.
  - Token admin dikirim melalui header `x-admin-session`.
    `Authorization: Bearer <anon-key>` tetap dipakai untuk gateway Supabase.
  - Bootstrap pertama memakai `ADMIN_INITIAL_PIN`; baris `admin_settings`
    dimulai dengan algoritma `uninitialized` agar rate limit juga berlaku
    sebelum PIN pertama dibuat.
  - Verifikasi PIN untuk sesi cloud selalu membutuhkan server; local UI guard
    bukan otorisasi cloud.
  - Build saat ini tidak menyediakan offline local-only unlock. Jika owner
    memilih mengaktifkannya, unlock hanya boleh membuka edit cache lokal dan
    tidak boleh mengotorisasi cloud mutation.
  - Route guard hanya UX. Setiap endpoint mutasi wajib memanggil
    `requireAdminSession` di server.
  - Audit log mencatat verifikasi, kegagalan, perubahan PIN, dan logout tanpa
    menyimpan PIN/token.
- **Konsekuensi:** Jika `ADMIN_PIN_PEPPER` dirotasi, PIN lama tidak valid dan
  harus di-bootstrap/diubah. `ADMIN_INITIAL_PIN` harus dihapus setelah setup.
  Semua mutation endpoint Sprint 07 wajib menggunakan header dan helper yang
  sama. PIN/sesi tidak pernah mengotorisasi cloud mutation secara offline.

## D-019 — Pull publik, outbox sync, dan resolusi konflik

- **Tanggal:** 13 November 2026
- **Status:** Diadopsi untuk Sprint 07
- **Konteks:** Aplikasi harus tetap read-only untuk publik, mengirim mutasi admin
  secara idempoten, dan tidak menimpa perubahan finansial secara diam-diam.
- **Keputusan:**
  - Public pull memakai RPC paginasi keyset `(updated_at, id)` untuk group/debt
    dan `(created_at, id)` untuk payment, dengan limit 1–500.
  - Pull publik tidak pernah membuat/mengubah outbox dan tidak menimpa baris
    lokal dengan `sync_state` pending/conflict.
  - Semua mutasi admin dikirim satu per satu melalui `admin-sync`; server
    memverifikasi `x-admin-session`, lalu `admin_apply_mutation` melakukan
    idempotency, validasi, version check, mutasi, dan audit dalam satu transaksi.
  - Urutan dependency: group create/update/archive → debt → payment → group
    delete. Item yang dependency-nya belum synced dilewati.
  - Network/5xx memakai exponential backoff + jitter; auth failure menyimpan
    queue dan berhenti sampai admin login kembali; validation failure ditandai
    gagal tanpa retry otomatis.
  - Konflik versi menyimpan `server_version`, `server_updated_at`, dan
    `server_row` di `sync_queue.conflict_data`. UI menyediakan:
    - “Muat ulang server”: terapkan snapshot server.
    - “Pertahankan lokal”: set versi lokal ke versi server, enqueue operasi baru,
      lalu sync ulang.
  - Drift schema dinaikkan ke v3 dengan reset destruktif karena aplikasi belum
    release.
  - Sinkronisasi foreground dipicu start/resume/connectivity/manual. WorkManager
    periodik 15 menit bersifat best-effort.
- **Konsekuensi:** Public RPC tidak mengekspos `version`; baris hasil pull dari
  perangkat lain dapat memunculkan konflik pada edit admin pertama dan harus
  diselesaikan lewat UI. Full manual pull melakukan rekonsiliasi group yang
  sudah dihapus server, tetapi mempertahankan group yang masih direferensikan
  debt pending/conflict agar FK tidak mengubah data unsynced. Incremental pull
  tidak menghapus baris. Background worker perlu diverifikasi di perangkat
  Android nyata.

## D-020 — Reminder lokal berbasis preferensi perangkat

- **Tanggal:** 14 November 2026
- **Status:** Diadopsi untuk Sprint 08
- **Konteks:** Reminder harus bekerja tanpa internet, tidak boleh mengubah data
  bisnis, dan konfigurasinya hanya boleh dilakukan admin.
- **Keputusan:**
  - Preferensi reminder disimpan di `local_settings` (SQLite) dan tidak
    disinkronkan: enabled, offset H-3/H-1/H, dan waktu lokal (default 09:00).
  - Scheduler memakai `DebtOverview` aktif; hanya hutang dengan sisa > 0 dan
    due date yang dijadwalkan.
  - Rekonsiliasi melakukan cancel-all lalu schedule ulang saat startup, resume,
    atau data hutang/pembayaran berubah. Ini menangani due-date change,
    pembayaran lunas, archive, dan timezone change.
  - Zona waktu perangkat dibaca lewat `flutter_timezone`; fallback aman ke
    default timezone package bila plugin tidak tersedia.
  - Exact alarm dipakai bila diizinkan; jika tidak, scheduler memakai inexact
    alarm dan UI menjelaskan bahwa notifikasi dapat tertunda.
  - Notifikasi memakai channel lokal dan teks yang menegaskan bukan bukti
    pembayaran.
  - Public mode hanya menampilkan daftar jatuh tempo; kontrol reminder hanya
    muncul saat admin unlocked. (Digantikan oleh D-024: reminder publik
    device-local tanpa mutasi bisnis.)
  - Drift schema dinaikkan ke v4 dengan reset destruktif.
- **Konsekuensi:** Perilaku notifikasi, permission prompt, exact alarm, boot
  rescheduling, dan timezone change perlu diverifikasi di perangkat Android
  fisik. Build Android memerlukan compileSdk 37 dan core-library desugaring
  untuk `flutter_local_notifications`. Reminder lokal tidak menyinkronkan
  preferensi antarperangkat.

## D-021 — Offline-first tetap, hard delete terbatas, dan full-pull reconciliation

- **Tanggal:** 14 November 2026
- **Status:** Disetujui owner untuk Sprint 09
- **Konteks:** Owner sempat mempertimbangkan CRUD online-only, tetapi memilih
  mempertahankan offline-first karena arsitektur outbox sudah terbukti dan
  aplikasi harus tetap berguna tanpa internet.
- **Keputusan:**
  - Admin CRUD tetap menulis ke SQLite + outbox secara atomik; server
    authorization tetap wajib saat sync.
  - Hard delete group mengikuti kebijakan yang ada: hutang dipindahkan ke
    Unassigned, lalu group dihapus.
  - Hard delete debt hanya boleh jika debt belum memiliki payment. Debt yang
    sudah memiliki payment hanya boleh diarsipkan.
  - Payment tetap append-only dan tidak pernah dihapus.
  - Hard delete memerlukan konfirmasi eksplisit dan audit server.
  - Public pull menjalankan full reconciliation saat startup (maksimal sekali
    per 24 jam) dan saat manual sync. Baris lokal `synced` yang tidak ada lagi
    di server dihapus; baris `pending`/`conflict` tidak dihapus otomatis.
- **Konsekuensi:** Perlu mutation delete di backend/local/UI, full-pull
  reconciliation untuk debt/group, dan test hard delete. Data yang sudah
  dihapus tidak dapat dipulihkan dari aplikasi; backup/export harus tersedia
  sebelum aksi delete.

## D-022 — Backup/export JSON dan restore-merge yang aman

- **Tanggal:** 14 November 2026
- **Status:** Disetujui owner untuk Sprint 09
- **Konteks:** Hard delete dan permintaan owner membutuhkan mekanisme backup
  yang tidak membocorkan metadata internal dan tidak menimpa data cloud secara
  diam-diam.
- **Keputusan:**
  - Backup/export berupa JSON dengan `schema_version`, `exported_at`,
    `debt_groups`, `debts`, dan `payments`.
  - File hanya berisi field bisnis; `version`, `operation_id`, sync metadata,
    session, audit, dan token tidak diekspor.
  - Export tersedia untuk admin dan disimpan melalui share sheet/file picker.
  - Restore/import bersifat admin-only, divalidasi, dan **merge by ID**: data
    yang belum ada ditambahkan, data yang sudah ada tidak ditimpa atau dihapus,
    dan payment duplikat diabaikan.
  - Restore lokal tidak menimpa cloud secara otomatis. Full destructive
    replace/cloud restore di luar scope v1 dan memerlukan keputusan terpisah.
  - UI menyarankan export sebelum hard delete.
- **Konsekuensi:** Backup dapat memulihkan data lokal yang hilang, tetapi bukan
  pengganti disaster recovery cloud. Restore harus memiliki preview, validasi
  referensi group→debt→payment, dan konfirmasi.

## D-023 — Tanpa app lock, tanpa PIN recovery UI

- **Tanggal:** 14 November 2026
- **Status:** Disetujui owner untuk v1
- **Keputusan:**
  - Tidak ada device-level app lock atau enkripsi SQLite tambahan di v1.
    Keterbatasan ini harus didokumentasikan.
  - Tidak ada fitur PIN recovery di aplikasi. Jika PIN hilang, owner harus
    melakukan reset server-side melalui prosedur operator/secret yang
    terdokumentasi.
  - `ADMIN_INITIAL_PIN` hanya untuk bootstrap dan harus dihapus setelah PIN
    pertama berhasil dibuat.
  - Semua data bisnis tetap publik melalui RPC read-only; internal metadata
    tetap privat.
- **Konsekuensi:** Kehilangan PIN berarti admin tidak dapat masuk sampai reset
  server dilakukan. Kehilangan perangkat tidak dilindungi app lock lokal;
  dokumentasikan risiko ini pada release notes.

## D-024 — Reminder lokal dapat diakses publik

- **Tanggal:** 14 November 2026
- **Status:** Disetujui owner untuk v1
- **Konteks:** Reminder hanya menyimpan preferensi lokal di perangkat dan tidak
  mengubah data bisnis cloud. Owner ingin pengguna publik dapat memakai reminder
  tanpa harus membuka sesi admin.
- **Keputusan:**
  - Halaman Reminder dan seluruh kontrolnya dapat diakses tanpa PIN admin.
  - Public dapat mengaktifkan H-3/H-1/H, memilih waktu lokal, memberikan izin
    notifikasi/exact alarm, dan menjadwalkan ulang reminder.
  - Preferensi tetap disimpan di `local_settings`, tidak disinkronkan, dan tidak
    membuat outbox atau mutasi bisnis.
  - Public tetap read-only terhadap group, hutang, pembayaran, dan data cloud.
  - Reminder hanya membaca data bisnis publik dari database lokal.
- **Konsekuensi:** Siapa pun yang memakai perangkat dapat mengubah jadwal
  notifikasi lokal. Ini tidak memberi akses tulis ke data cloud dan tidak
  mengubah otorisasi admin. Preferensi reminder tetap per perangkat.

## D-025 — In-app update dari GitHub Release publik

- **Tanggal:** 14 November 2026
- **Status:** Disetujui owner dan selesai; rilis `v1.0.1`/`v1.0.2` tersedia dan
  verifikasi perangkat owner-reported passed di I2505 (Android 16)
- **Konteks:** Aplikasi didistribusikan sebagai APK langsung, bukan melalui Play
  Store. Repo `alamsyahkuba/debt_reminder` sudah public, sehingga updater dapat
  membaca GitHub Release tanpa token.
- **Keputusan:**
  - Tombol **Cek Update** tersedia untuk publik dan admin dan hanya berjalan
    manual; tidak ada polling startup pada v1.
  - Sumber update adalah GitHub Release stabil repo utama. Updater mengabaikan
    draft/prerelease.
  - Setiap release stabil memuat APK, `.sha256`, dan `latest.json`. Manifest
    memakai `schema_version` 1 dan `build_number` sebagai pembanding utama.
  - Download hanya dari HTTPS dengan host allowlist GitHub, memeriksa ruang
    penyimpanan, memverifikasi SHA-256 dan ukuran, lalu native Android
    memverifikasi package, version code, dan signing certificate sebelum
    membuka installer sistem.
  - Installer memakai custom MethodChannel + FileProvider; plugin installer
    pihak ketiga tidak dipakai. Android tetap meminta konfirmasi pengguna.
  - Release notes dirender sebagai teks polos. Tidak ada token GitHub atau
    `service_role` di aplikasi.
  - Update tidak mengubah schema bisnis, Supabase, outbox, sesi admin, atau
    preferensi reminder.
- **Konsekuensi:** APK harus selalu ditandatangani dengan keystore yang sama.
  Pengguna harus mengizinkan **Install unknown apps** untuk aplikasi ini. Update
  tidak dapat dipasang diam-diam dan tidak dapat dilakukan tanpa release stabil
  yang berisi `latest.json`. Jika update check gagal, aplikasi tetap dapat
  dipakai normal.

## D-026 — Bulk insert hutang atomik

- **Tanggal:** 14 November 2026
- **Status:** Disetujui owner; implementasi, test otomatis, dan deploy cloud
  selesai; verifikasi perangkat pending
- **Konteks:** Admin perlu memasukkan banyak hutang tanpa membuat satu form
  per hutang. Aplikasi tetap offline-first dan mutasi admin harus memiliki
  idempotency serta otorisasi server.
- **Keputusan owner:**
  - Generator angsuran otomatis di `/debts/bulk`: nama dasar, jumlah angsuran,
    dan nominal per angsuran.
  - Judul hutang memakai format `Nama 1`, `Nama 2`, dst.
  - Maksimal 50 hutang per batch.
  - Satu group untuk seluruh batch; tanggal default opsional otomatis
    diterapkan.
  - Checklist **jatuh tempo per bulan**: angsuran 1 memakai tanggal default,
    angsuran berikutnya +1 bulan bertahap.
  - Satu RPC server atomik untuk seluruh batch.
  - Dialog konfirmasi jika batch berisi lebih dari satu hutang.
- **Implementasi:**
  - `DebtRepository.createMany` menulis semua hutang dan satu outbox
    `debt_batch` dalam satu transaksi SQLite.
  - Worker sync mengirim satu operation ID untuk batch; server memakai
    `admin_bulk_create_debts` untuk idempotency, insert all-or-nothing, dan audit
    `sync.batch_create`.
  - Jika satu baris ditolak server, seluruh batch rollback dan outbox tetap ada
    dengan status failed.
- **Konsekuensi:** Tidak ada partial server insert. Kesalahan satu baris
  menggagalkan seluruh batch dan memerlukan perbaikan/retry. Import CSV/Excel
  belum termasuk; input masih manual.
