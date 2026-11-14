# Debt Reminder

Aplikasi Android untuk mencatat, mengelompokkan, memantau, dan mengingatkan
hutang/piutang. Dibangun dengan Flutter dan disiapkan untuk backend Supabase
serta penyimpanan lokal offline-first.

Data bisnis terdiri dari **group hutang, hutang, dan pembayaran**. Tidak ada
modul pelanggan.

## Status

Sprint 00–03 sudah memiliki implementasi awal, tetapi **plan telah direvisi**
pada 12 November 2026:

- hanya dua peran: owner/admin dan publik;
- tidak ada entitas pelanggan;
- group tetap ada;
- semua field bisnis dapat dibaca publik;
- admin tetap memakai PIN dan sesi server-side;
- read-only device enrollment dihapus;
- database sudah di-reset karena aplikasi belum rilis.

Sprint 01R sudah menyelesaikan rework cloud: schema tanpa customers/read_devices,
public read RPC, dan RLS read-only. Sprint 02R/03R sudah membersihkan schema
lokal, repository, UI, dan test customer. Sprint 04 menambahkan debt management
lengkap tanpa customer. Sprint 05 menambahkan form pembayaran, penolakan
overpayment, histori append-only, dan dashboard turunan. Sprint 06 menambahkan
PIN admin 6 digit, sesi server 15 menit, rate limit, secure storage, route
guard, dan perubahan PIN. Sprint 07 menambahkan public pull paginasi, outbox
sync idempoten, retry/backoff, conflict resolution, status sync, manual sync,
connectivity trigger, dan WorkManager best-effort. Sprint 08 menambahkan
reminder lokal H-3/H-1/H, permission notifikasi, fallback exact alarm, timezone,
dan rekonsiliasi jadwal. Sprint 09 menambahkan hard delete terbatas, full-pull
reconciliation, backup/export JSON dengan restore-merge, branding **Debt
Reminder**, package `com.debtreminder.app`, versi `1.0.0+1`, dan release signing.
Cloud migration/Edge Functions sudah dideploy, PIN admin sudah bootstrap, APK
release bertanda tangan sudah dibangun, dan seluruh pengujian perangkat di
I2505 dilaporkan lolos oleh owner. GitHub release automation sudah dijalankan:
dry run dan rilis otomatis pertama `v1.0.0` berhasil. In-app update sudah
diimplementasikan dan diuji owner: `v1.0.1+2` dan `v1.0.2+3` dipublikasikan
dengan APK, `.sha256`, dan `latest.json`; alur cek/download/verifikasi/install
dan preservasi data dilaporkan lolos di I2505. Sprint 12 menambahkan bulk insert
hutang manual hingga 50 baris dengan satu group per batch dan RPC server atomik;
implementasi, test, dan deploy cloud sudah selesai, tinggal uji perangkat. Rilis v1 didistribusikan sebagai APK; AAB dan Play Console tidak
termasuk scope. Lihat [`plans/STATUS.md`](plans/STATUS.md) dan
[`plans/RELEASE_CHECKLIST.md`](plans/RELEASE_CHECKLIST.md).

Spesifikasi produk dan sprint ada di [`plans/`](plans/).

## Prasyarat

- Flutter stable 3.47.7 atau versi kompatibel (Dart 3.13.5).
- Android SDK dengan platform 37 dan toolchain yang lolos `flutter doctor`.
- Build Android memakai `compileSdk 37` dan core library desugaring untuk
  `flutter_local_notifications`.
- Untuk menjalankan: emulator Android atau perangkat fisik dengan USB
  debugging.

## Menjalankan aplikasi

```bash
flutter pub get
flutter run
```

Aplikasi tetap dapat membaca data lokal tanpa konfigurasi Supabase. Login admin
membutuhkan `SUPABASE_URL`, anon key, dan Edge Function `admin-pin` yang sudah
dikonfigurasi; lihat [`supabase/README.md`](supabase/README.md).

## Update aplikasi

Pengguna publik dan admin dapat membuka **Pengaturan → Pembaruan aplikasi** lalu
menekan **Cek Update**. Pemeriksaan berjalan manual dan membaca GitHub Release
stabil dari `alamsyahkuba/debt_reminder`. Jika build remote lebih baru, aplikasi
menampilkan versi, ukuran, dan catatan rilis sebagai teks polos.

**Download & Pasang** memeriksa ruang penyimpanan, mengunduh APK dari host
GitHub yang diizinkan melalui HTTPS, menampilkan progress, memverifikasi
SHA-256 dan ukuran file, lalu native Android memverifikasi package
`com.debtreminder.app`, version code, dan sertifikat signing sebelum membuka
installer sistem. Android tetap meminta
pengguna menyetujui instalasi dan izin **Install unknown apps**. Aplikasi tidak
menyimpan token GitHub dan tidak melakukan update diam-diam.

Setiap release stabil wajib memiliki asset APK, `.apk.sha256`, dan `latest.json`.
Update tidak mengubah data bisnis, database Supabase, outbox, sesi admin, atau
preferensi reminder. Jika pengecekan gagal atau perangkat offline, aplikasi
tetap dapat dipakai normal. Detail kontrak manifest dan checklist uji ada di
[`plans/sprints/SPRINT_11_IN_APP_UPDATE.md`](plans/sprints/SPRINT_11_IN_APP_UPDATE.md)
dan [`plans/RELEASE_CHECKLIST.md`](plans/RELEASE_CHECKLIST.md).

## Bulk insert hutang

Admin dapat membuka **Semua Hutang → Tambah Banyak** untuk mengisi beberapa
hutang sekaligus:

- 1–50 baris per batch, satu group untuk seluruh batch.
- Jatuh tempo default opsional dan dapat dioverride per baris.
- Baris kosong diabaikan; baris terisi sebagian ditolak.
- Satu transaksi SQLite menyimpan semua hutang dan satu outbox `debt_batch`.
- Satu RPC server atomik `admin_bulk_create_debts` membuat seluruh batch atau
  rollback semua jika ada satu baris invalid.
- Dialog konfirmasi muncul untuk batch lebih dari satu hutang.

Detail keputusan, test, dan status implementasi ada di
[`plans/sprints/SPRINT_12_BULK_DEBT_INSERT.md`](plans/sprints/SPRINT_12_BULK_DEBT_INSERT.md).

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
   | `SEED_DEMO_DATA` | `true` hanya untuk development; mengisi data demo lokal |

3. Jalankan:

   ```bash
   flutter run --dart-define-from-file=config/app_config.local.json
   ```

`config/*.json` diabaikan Git, kecuali `config/app_config.example.json`.
Jangan pernah menaruh Supabase `service_role` key di aplikasi, repository, atau
argumen build client.


## Reminder

- Publik dan admin dapat mengaktifkan H-3, H-1, dan/atau hari H serta memilih
  waktu lokal.
- Jadwal dikelola lokal dan direkonsiliasi saat startup, resume, atau data
  hutang/pembayaran berubah.
- Hutang lunas dan diarsipkan tidak memiliki reminder aktif.
- Jika izin notifikasi atau exact alarm tidak tersedia, aplikasi menjelaskan
  fallback-nya.
- Konfigurasi reminder hanya mengubah preferensi lokal; tidak membuat mutasi
  bisnis atau outbox.

## Database lokal

Drift/SQLite schema v4 memakai tabel bisnis:

- `debt_groups`
- `debts`
- `payments`
- `sync_queue` (termasuk `conflict_data`)
- `sync_metadata`
- `local_settings` (preferensi reminder perangkat)

Tidak ada tabel `customers`, `customer_id`, atau `read_devices`. Migrasi
v1→v4 bersifat destruktif karena aplikasi belum release; database lama
di-reset.

- UI membaca data melalui repository dan Drift stream; jangan query Supabase
  langsung dari widget.
- Mutasi admin dan outbox entry disimpan dalam satu transaksi SQLite.
- Public pull memakai RPC read-only paginasi dan tidak membuat outbox.
- Admin sync mengirim outbox lewat Edge Function `admin-sync` dengan sesi
  admin; group → debt → payment, lalu group delete.
- Pembayaran bersifat append-only, termasuk trigger SQLite yang menolak
  perubahan field finansial. Metadata sync tetap boleh diperbarui.
- Hard delete debt hanya untuk hutang tanpa payment; hutang dengan payment harus
  diarsipkan. Backup/export JSON admin-only dan restore-merge tersedia dari
  Pengaturan.
- Full-pull reconciliation berjalan saat startup maksimal sekali per 24 jam dan
  saat sinkronisasi manual. Baris `synced` yang sudah tidak ada di server
  dihapus; baris `pending`/`conflict` dan hutang dengan pembayaran lokal tetap
  dipertahankan.
- Konflik versi disimpan dan dapat dimuat ulang dari server atau dipertahankan
  lokal dari halaman Pengaturan.
- Sinkronisasi berjalan foreground, saat konektivitas kembali, manual, dan
  best-effort WorkManager 15 menit.
- Reminder lokal dijadwalkan dari preferensi perangkat; notifikasi tidak
  membutuhkan internet dan bukan bukti pembayaran.
- Kode Drift dihasilkan dengan:

  ```bash
  dart run build_runner build
  ```

Data demo hanya untuk development:

```bash
flutter run --dart-define=SEED_DEMO_DATA=true
```

Seed demo tidak membuat outbox dan tidak boleh dipakai dengan database cloud
nyata. Database lokal tidak dienkripsi; app lock tidak dipakai di v1. PIN admin
tidak dapat dipulihkan dari aplikasi. Kedua keterbatasan ini didokumentasikan
pada [`plans/RELEASE_CHECKLIST.md`](plans/RELEASE_CHECKLIST.md).

## Build release

Release harus dibangun dengan konfigurasi Supabase remote; tanpa
`--dart-define-from-file` atau `--dart-define`, aplikasi akan berjalan tanpa
konfigurasi cloud.

Workflow release otomatis ada di
[`.github/workflows/release.yml`](.github/workflows/release.yml). Workflow ini
menjalankan test, bump versi/build, membuat changelog dengan `git-cliff`,
membangun APK bertanda tangan, membuat `latest.json`, membuat tag, dan
menerbitkan GitHub Release berisi APK, `.sha256`, dan manifest update. AAB dan
Play Console tidak termasuk scope.

Rilis `v1.0.1+2` dan `v1.0.2+3` sudah dipublikasikan dengan APK, `.sha256`, dan
`latest.json`; alur in-app update sudah diuji dan dilaporkan lolos oleh owner.
Rilis berikutnya menggunakan alur yang sama:

```bash
gh workflow run release.yml -f bump=auto -f dry_run=true
gh run watch
gh workflow run release.yml -f bump=auto
```

`auto` membaca conventional commits sejak tag terakhir. Override manual:
`-f bump=patch`, `minor`, atau `major`. `build-only` hanya untuk dry run.

Secret yang dibutuhkan: `RELEASE_TOKEN`, `ANDROID_KEYSTORE_BASE64`,
`ANDROID_STORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`,
`SUPABASE_URL`, dan `SUPABASE_ANON_KEY`. `RELEASE_TOKEN` harus diizinkan
melewati ruleset `main`.

Manual fallback:

```bash
flutter build apk --release \
  --dart-define-from-file=config/app_config.local.json
```

APK ada di `build/app/outputs/flutter-apk/app-release.apk`. Release signing
membaca `android/key.properties` di luar Git.

## Kualitas kode

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

## Backend Supabase

Schema, RLS, idempotency registry, public read RPCs, dan Edge Function helpers
ada di [`supabase/`](supabase/README.md).

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

Kebijakan cloud target:

- **Public read-only**: anon dapat membaca seluruh field bisnis melalui RPC
  read-only.
- Anon tidak dapat SELECT base table langsung.
- Anon tidak dapat INSERT/UPDATE/DELETE.
- Semua mutation admin melalui Edge Function dengan sesi admin server-side.
- Data admin, audit, sesi, PIN, token, dan metadata internal tetap privat.
- Tidak ada `customers`, `read_devices`, atau device enrollment.

Schema cloud lokal sudah di-rework dan di-reset. Linked project
`rtgescanjpzkytcddnke` sudah menerima seluruh migration, `admin-pin` dan
`admin-sync` aktif, serta PIN admin sudah bootstrap. Detail ada di
[`supabase/README.md`](supabase/README.md).

CI GitHub Actions menjalankan pemeriksaan Flutter serta test database/helper
Edge Function pada push ke `main` dan setiap pull request.

## Struktur utama

Target akhir:

```text
lib/
  app/                 # App, router, theme, shell, drawer, bootstrap
  core/                # Config, errors, logging, network, security, utils
  data/
    local/             # Drift database, DAOs, demo seed
    repositories/      # Implementasi repository + outbox
    sync/              # Sync service, queue, worker, conflict resolver
  domain/
    entities/          # Entity domain: group, debt, payment
    repositories/      # Kontrak repository
    validation/        # Validasi domain
  features/            # Dashboard, groups, debts, payments, reminders, admin, settings
  shared/              # Widget lintas fitur
  main.dart
test/                  # Unit, repository, database, widget test
config/                # Contoh konfigurasi (nilai lokal di-ignore)
plans/                 # Spesifikasi dan status sprint
```

Tidak ada lagi `features/customers` atau artefak device-enrollment.

## Catatan pengembangan

- UI selalu membaca data dari database lokal melalui repository.
- Mutasi admin dan outbox harus berada dalam transaksi SQLite yang sama.
- Public mode tidak boleh membuat mutation atau outbox.
- Semua operasi admin akan diverifikasi server-side.
- Nominal uang disimpan sebagai integer rupiah.
- Semua mutation admin memerlukan sesi server-side; route guard dan sesi admin
  sudah aktif. Build lokal tetap bukan pengganti otorisasi server.
- Release signing membaca `android/key.properties` di luar Git. Jangan commit
  keystore, password, atau `key.properties`.
- Jangan mengedit `lib/data/local/app_database.g.dart` secara manual; ubah
  schema lalu jalankan build_runner.
