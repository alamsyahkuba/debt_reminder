# Catatan Hutang

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
- database akan di-reset.

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
dan rekonsiliasi jadwal. Proyek siap melanjutkan ke Sprint 09.
Lihat [`plans/STATUS.md`](plans/STATUS.md).

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

- Admin dapat mengaktifkan H-3, H-1, dan/atau hari H serta memilih waktu lokal.
- Jadwal dikelola lokal dan direkonsiliasi saat startup, resume, atau data
  hutang/pembayaran berubah.
- Hutang lunas dan diarsipkan tidak memiliki reminder aktif.
- Jika izin notifikasi atau exact alarm tidak tersedia, aplikasi menjelaskan
  fallback-nya.
- Public mode hanya menampilkan tanggal jatuh tempo dan tidak dapat mengubah
  konfigurasi reminder.

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
nyata. Database lokal belum dienkripsi; keputusan app lock/encryption masih
menunggu owner.

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

Schema cloud lokal sudah di-rework dan di-reset. Cloud project belum di-push.
Detail ada di [`supabase/README.md`](supabase/README.md).

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
- Group/debt/payment management saat ini dapat diakses secara lokal tanpa PIN;
  route guard dan sesi admin ditambahkan pada Sprint 06. Jangan distribusikan
  build ini sebagai release sebelum gate tersebut aktif.
- Jangan mengedit `lib/data/local/app_database.g.dart` secara manual; ubah
  schema lalu jalankan build_runner.
