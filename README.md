# Catatan Hutang

Aplikasi Android untuk mencatat, mengelompokkan, memantau, dan mengingatkan
hutang/piutang. Dibangun dengan Flutter dan disiapkan untuk backend Supabase
serta penyimpanan lokal offline-first.

## Status

Sprint 00 (Foundation) menyediakan kerangka aplikasi, tema Material 3,
navigasi, drawer, konfigurasi environment, lint, CI, dan placeholder screen.
Sprint 01 (Cloud schema & security) menyediakan schema Supabase, RLS, sesi
admin, idempotency, dan fondasi perangkat read-only. Database lokal Drift,
autentikasi admin di aplikasi, CRUD, dan sync belum aktif.

Spesifikasi produk dan sprint ada di [`plans/`](plans/), dengan status terbaru
di [`plans/STATUS.md`](plans/STATUS.md).

## Prasyarat

- Flutter stable 3.47.7 atau versi kompatibel (Dart 3.13.5).
- Android SDK dan toolchain yang lolos `flutter doctor`.
- Untuk menjalankan: emulator Android atau perangkat fisik dengan USB
  debugging.

## Menjalankan aplikasi

```bash
flutter pub get
flutter run
```

Aplikasi dapat berjalan tanpa konfigurasi Supabase pada tahap fondasi ini.

## Konfigurasi environment

Konfigurasi dikirim saat build melalui `--dart-define`, bukan file `.env` yang
dibundel sebagai asset.

1. Salin contoh konfigurasi:

   ```bash
   cp config/app_config.example.json config/app_config.local.json
   ```

2. Isi nilai lokal pada file tersebut:

   | Key | Keterangan |
   |---|---|
   | `APP_ENV` | `development`, `staging`, atau `production` |
   | `SUPABASE_URL` | URL project Supabase |
   | `SUPABASE_ANON_KEY` | Anon/publishable key (bukan secret) |

3. Jalankan:

   ```bash
   flutter run --dart-define-from-file=config/app_config.local.json
   ```

`config/*.json` diabaikan Git, kecuali `config/app_config.example.json`.
Jangan pernah menaruh Supabase `service_role` key di aplikasi, repository, atau
argumen build client.

## Kualitas kode

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

## Backend Supabase

Schema, RLS, idempotency registry, dan Edge Function helpers ada di
[`supabase/`](supabase/README.md).

```bash
npx --yes supabase@3.1.0 db start
npx --yes supabase@3.1.0 db reset
npx --yes supabase@3.1.0 test db
npx --yes supabase@3.1.0 db lint
```

Test helper Edge Function membutuhkan Deno 2:

```bash
cd supabase/functions
deno fmt --check
deno check _shared/*.ts
deno lint
deno test
```

Kebijakan cloud v1: **tidak ada public read**. RLS aktif di semua tabel, tanpa
policy anon/authenticated. Perangkat read-only yang di-enroll admin boleh
menarik data terbaru dengan token perangkat revocable; perangkat lain hanya
membaca cache lokal. Detail dan aturan migration ada di
[`supabase/README.md`](supabase/README.md).

CI GitHub Actions menjalankan pemeriksaan Flutter serta test database/helper
Edge Function pada push ke `main` dan setiap pull request.

## Struktur utama

```text
lib/
  app/                 # App, router, theme, shell, drawer
  core/                # Config, errors, logging, network, security, utils
  features/            # Screen per fitur
  shared/              # Widget lintas fitur
  main.dart
test/                  # Unit dan widget test
config/                # Contoh konfigurasi (nilai lokal di-ignore)
plans/                 # Spesifikasi dan status sprint
```

## Catatan pengembangan

- UI nantinya selalu membaca data dari database lokal melalui repository.
- Mutasi lokal dan outbox harus berada dalam transaksi SQLite yang sama.
- Semua operasi admin akan diverifikasi server-side.
- Nominal uang disimpan sebagai integer rupiah.
