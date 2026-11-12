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
