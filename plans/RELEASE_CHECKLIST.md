# Release Checklist — Debt Reminder v1.0.0

Dokumen ini adalah gate rilis Android. Jangan distribusikan build sebagai
release sampai semua item wajib tercentang dan diverifikasi pada perangkat
fisik.

## Identitas rilis

| Item | Nilai |
|---|---|
| Nama aplikasi | Debt Reminder |
| Application ID | `com.debtreminder.app` |
| Version name / code | `1.0.0+1` |
| Icon | `assets/branding/app_icon.png` |
| Splash | `assets/branding/splash_logo.png` + wordmark |
| Release signing | `android/key.properties`, keystore di luar repo |
| Backend | Supabase project `rtgescanjpzkytcddnke` |

Naikkan build number (`1.0.0+2`, `1.0.0+3`, ...) untuk setiap distribusi baru.
Jangan mengubah application ID setelah rilis pertama.

## Sign-off

- Tanggal: 14 November 2026
- Perangkat: I2505 (`10DG3404HM000HH`), Android 16 / API 36
- Status: baseline v1 dan in-app update owner-reported passed; verifikasi bulk
  insert Sprint 12 masih pending (bukan hasil otomasi perangkat)
- Distribusi: APK bertanda tangan langsung; AAB/Play Console tidak dipakai

## Wajib sebelum rilis

- [x] `dart format --output=none --set-exit-if-changed .` bersih.
- [x] `flutter analyze` tanpa issue.
- [x] `flutter test` seluruh suite lulus (termasuk bulk insert).
- [x] Deno handler tests dan pgTAP bulk insert lulus.
- [x] Migration bulk dan Edge Function `admin-sync` sudah dideploy ke cloud.
- [ ] Bulk insert sudah diuji pada perangkat fisik.
- [x] `deno fmt --check`, `deno check`, `deno lint`, `deno test` lulus.
- [x] pgTAP seluruh suite lulus pada schema yang akan dideploy.
- [x] `flutter build apk --debug` berhasil.
- [x] `flutter build apk --release` berhasil dan ditandatangani keystore rilis.
- [x] File keystore di `android/key.properties` valid (bukan 0 byte) dan alias
      dapat dibuka dengan password yang dikonfigurasi.
- [x] APK release diverifikasi: package, version, signature, icon, dan splash.
- [x] APK release dibangun dengan `config/app_config.local.json` sehingga URL
      dan anon key Supabase remote tertanam.
- [x] Tidak ada secret, keystore, password, atau service-role key di repo/APK.
- [x] Tidak ada `customers`, `customer_id`, `read_devices`, atau device
      enrollment di schema, kode, UI, dan test.
- [x] Anon hanya dapat membaca melalui public RPC; mutasi anon ditolak.
- [x] Tabel internal, RPC admin, audit, sesi, dan PIN tidak dapat diakses anon.
- [x] Remote migration push dan deploy `admin-pin`/`admin-sync` dikonfirmasi.
- [x] Secret server terpasang; `ADMIN_INITIAL_PIN` dihapus setelah bootstrap.
- [x] PIN admin di-bootstrap (`admin_settings.pin_hash_algorithm =
      pbkdf2_sha256`).
- [x] Login server berhasil dari aplikasi pada perangkat fisik.
- [x] Perangkat fisik tersedia dan lolos checklist perangkat di bawah.

## Deploy cloud

Jalankan dari root repo setelah login/link Supabase:

```bash
npx --yes supabase@3.1.0 migration list --remote
npx --yes supabase@3.1.0 db push --remote
npx --yes supabase@3.1.0 functions deploy admin-pin --remote
npx --yes supabase@3.1.0 functions deploy admin-sync --remote
npx --yes supabase@3.1.0 secrets list
npx --yes supabase@3.1.0 functions list
```

Verifikasi konfigurasi tanpa menampilkan nilai secret:

- `ADMIN_SESSION_JWT_SECRET` ada dan minimal 32 karakter.
- `ADMIN_PIN_PEPPER` ada dan kuat.
- `ADMIN_INITIAL_PIN` hanya sementara untuk bootstrap.
- Client memakai `SUPABASE_URL` dan anon/publishable key, bukan service role.

Bootstrap PIN:

1. Login sekali dari aplikasi memakai `ADMIN_INITIAL_PIN`.
2. Pastikan `admin_settings.pin_hash_algorithm = 'pbkdf2_sha256'`.
3. Hapus secret bootstrap:

   ```bash
   npx --yes supabase@3.1.0 secrets unset ADMIN_INITIAL_PIN
   ```

4. Login ulang setelah secret dihapus untuk memastikan PIN tersimpan.

## Build dan verifikasi APK

Rilis v1 hanya didistribusikan sebagai APK. AAB dan Play Console tidak
termasuk dalam scope rilis ini.

```bash
flutter build apk --debug
flutter build apk --release --dart-define-from-file=config/app_config.local.json
```

Verifikasi:

```bash
# Ganti path sesuai Android SDK.
$ANDROID_HOME/build-tools/<versi>/aapt dump badging \
  build/app/outputs/flutter-apk/app-release.apk | head
$ANDROID_HOME/build-tools/<versi>/apksigner verify --print-certs \
  build/app/outputs/flutter-apk/app-release.apk
```

Pastikan output menunjukkan `package name='com.debtreminder.app'`,
`versionName='1.0.0'`, `versionCode='1'`, dan sertifikat rilis yang benar.

## GitHub Release automation

- [x] GitHub Secrets release sudah dibuat dan `RELEASE_TOKEN` dapat bypass
      ruleset `main`.
- [x] Ruleset `main` berstatus Active dan mengizinkan bypass actor yang dipakai
      `RELEASE_TOKEN`.
- [x] Dry run workflow `bump=initial` berhasil tanpa commit/tag/release.
- [x] Rilis otomatis pertama `v1.0.0` berhasil dan APK+checksum tersedia.
- [x] Rilis stabil berikutnya memiliki tiga asset: APK, `.apk.sha256`, dan
      `latest.json`. `v1.0.1+2` dan `v1.0.2+3` memenuhi kontrak ini; `v1.0.0`
      tetap historis tanpa `latest.json`.
- [x] `latest.json` berisi `schema_version: 1`, versi/build yang sama dengan
      APK, checksum SHA-256 yang cocok, ukuran byte, URL release, dan notes teks
      polos.
- [x] Rilis rutin `bump=auto` menaikkan versi/build dan changelog tanpa
      menurunkan build number.

## Verifikasi in-app update

Uji minimal dua build bertanda tangan dengan keystore yang sama:

1. Pasang build lama pada perangkat.
2. Publikasikan build baru sebagai release stabil yang berisi `latest.json`.
3. Buka **Pengaturan → Pembaruan aplikasi → Cek Update**.
4. Pastikan versi, ukuran, dan catatan rilis tampil sebagai teks polos.
5. Tekan **Download & Pasang**, amati progress, dan pastikan checksum valid.
6. Setujui installer Android; pastikan update terpasang dan data lokal, sesi
   admin, serta preferensi reminder tetap ada.
7. Uji **Install unknown apps** ditolak: aplikasi harus membuka pengaturan izin
   dan tidak memaksa install.
8. Uji negatif: checksum salah, signature berbeda, manifest hilang/rusak, dan
   URL di luar allowlist harus ditolak tanpa membuka installer.
9. Uji offline/rate limit: tampilkan error yang jelas dan tombol retry; aplikasi
   tetap dapat dipakai.
10. Uji pembatalan download: file parsial dihapus dan state kembali ke update
    tersedia.

Checklist perangkat tambahan:

- [x] Cek Update terlihat dan berfungsi tanpa PIN admin.
- [x] Download menampilkan progress dan dapat dibatalkan.
- [x] Ruang penyimpanan diperiksa sebelum download; penyimpanan penuh
      menampilkan error tanpa file parsial.
- [x] SHA-256, package, version code, dan signature diverifikasi sebelum
      installer dibuka.
- [x] Update dari build lama ke build baru mempertahankan database lokal.
- [x] Checksum salah/signature mismatch ditolak.
- [x] Izin unknown sources ditolak/diizinkan berperilaku benar.
- [x] Offline dan rate limit menampilkan retry tanpa crash.

Catatan: seluruh checklist in-app update diselesaikan owner di I2505
(Android 16) dan dilaporkan lolos. Perangkat Android 8–15 belum tersedia untuk
pengujian langsung.

## Verifikasi bulk insert

1. Pastikan migration `20261114140000_bulk_debt_insert.sql` dan Edge Function
   `admin-sync` versi baru sudah dideploy.
2. Login admin, buka **Semua Hutang → Tambah Banyak**.
3. Simpan 1, 5, dan 50 baris dengan satu group; uji jatuh tempo default
   otomatis, checklist per bulan (baris 1 = default, berikutnya +1 bulan), dan
   override per baris.
4. Pastikan daftar hutang, dashboard, dan group summary langsung bertambah.
5. Offline: simpan batch, restart aplikasi, reconnect; pastikan satu outbox
   `debt_batch` terkirim dan semua baris menjadi synced.
6. Uji satu baris invalid di server; pastikan seluruh batch rollback dan tidak
   ada data server parsial.
7. Uji batch >50, ID duplikat, group hilang, dan baris terisi sebagian.
8. Pastikan reminder untuk hutang baru dijadwalkan setelah batch tersimpan.
9. Pastikan publik tidak melihat tombol dan route `/debts/bulk` dijaga PIN.

Checklist:

- [ ] Admin-only bulk screen dan route guard.
- [ ] 1, 5, dan 50 baris tersimpan benar.
- [ ] Group batch, tanggal default otomatis, jadwal per bulan, dan override
      benar.
- [ ] Satu transaksi lokal + satu outbox `debt_batch`.
- [ ] Server batch atomik dan replay idempoten.
- [ ] Offline → reconnect → restart → synced.
- [ ] Dashboard/group summary/reminder benar.
- [ ] Negative cases ditolak tanpa data parsial.

## Checklist perangkat fisik

- [x] Fresh install APK release berhasil; tidak ada data lama.
- [x] Splash menampilkan logo dan nama **Debt Reminder** tanpa terpotong.
- [x] Icon launcher tampil benar (legacy dan adaptive).
- [x] Drawer, dashboard, daftar hutang, detail hutang, dan pengaturan terbuka.
- [x] Public read berhasil tanpa login; tombol mutasi tidak tampil.
- [x] Halaman Reminder dan kontrolnya dapat diakses tanpa PIN admin.
- [x] Login PIN server berhasil dari aplikasi pada perangkat fisik.
- [x] PIN salah terkena rate limit/lockout.
- [x] Sesi kedaluwarsa mengunci UI dan tidak menghapus outbox.
- [x] Admin CRUD, archive, move group, dan pembayaran berhasil di perangkat.
- [x] Offline create/update/archive/payment masuk outbox; reconnect sync sukses.
- [x] Restart aplikasi mempertahankan outbox dan konflik.
- [x] Full pull manual menghapus baris synced yang sudah tidak ada di server.
- [x] Baris pending/conflict tidak terhapus oleh full pull.
- [x] Hard delete hutang tanpa pembayaran berhasil dan tidak dapat dibatalkan.
- [x] Hard delete hutang dengan pembayaran ditolak dan UI menyuruh arsip.
- [x] Backup JSON dapat diekspor dan dibuka kembali.
- [x] Restore-merge menolak referensi rusak dan tidak menimpa data lama.
- [x] Notifikasi H-3/H-1/H muncul pada waktu lokal yang dipilih.
- [x] Izin notifikasi dan exact alarm ditangani dengan fallback yang jelas.
- [x] Reminder dibatalkan untuk hutang lunas/arsip dan dijadwalkan ulang setelah
      pembayaran.
- [x] Reboot perangkat menjadwalkan ulang reminder.
- [x] Perubahan timezone memindahkan instant pengingat dengan benar.
- [x] WorkManager/background sync berjalan best-effort; manual sync tetap ada.
- [x] Tidak ada crash atau data loss saat pindah foreground/background.

Catatan: seluruh checklist perangkat fisik diselesaikan owner di I2505 dan
dilaporkan lolos. Status ini **owner-reported**, bukan hasil otomasi. Bukti
quality gate otomatis ada di `plans/STATUS.md`.

## Known limitations v1

- Tidak ada app lock atau enkripsi SQLite tambahan. Siapa pun yang membuka
  perangkat yang sudah tidak terkunci dapat membaca data lokal.
- Semua data bisnis dapat dibaca publik melalui RPC read-only dengan anon key.
  Ini keputusan produk, bukan bug.
- Tidak ada PIN recovery UI. PIN hilang hanya dapat direset operator melalui
  prosedur server-side di bawah.
- `ADMIN_INITIAL_PIN` adalah bootstrap-only dan wajib dihapus setelah PIN dibuat.
- Hard delete hutang tidak dapat dibatalkan dari aplikasi. Ekspor backup lebih
  dahulu.
- Payment append-only: tidak ada edit/hapus pembayaran, termasuk oleh admin.
- Full-pull deletion reconciliation berjalan saat startup maksimal sekali per
  24 jam dan saat sync manual; bukan real-time.
- Restore-merge bersifat lokal-first. Baris baru masuk outbox dan dikirim saat
  sesi admin aktif. Jika server sudah memiliki ID yang sama tetapi lokal tidak,
  create dapat ditandai gagal; data lokal tetap dipertahankan dan tidak menimpa
  cloud.
- Tidak ada full destructive cloud restore di v1.
- AAB dan Play Console tidak termasuk scope rilis v1; distribusi dilakukan
  langsung memakai APK bertanda tangan.
- WorkManager bersifat best-effort; jangan mengandalkannya sebagai satu-satunya
  jalur sinkronisasi.
- Public pull tidak membawa `version`, sehingga edit admin pertama setelah pull
  dari perangkat lain dapat memunculkan konflik; UI menyediakan resolusi.
- Build memakai `compileSdk 37` dan desugaring karena
  `flutter_local_notifications`; AGP 9.1 masih memberi peringatan compileSdk di
  atas rekomendasi. Toolchain harus diuji ulang sebelum upgrade.
- Application ID berubah menjadi `com.debtreminder.app`; instalasi lama tidak
  dimigrasikan otomatis dan harus dianggap fresh install.
- Update aplikasi hanya diperiksa manual dari Pengaturan; tidak ada polling
  startup atau update background pada v1.
- Update membutuhkan release stabil yang berisi `latest.json`, APK, dan
  `.sha256`. APK harus ditandatangani dengan keystore yang sama.
- Android mewajibkan pengguna mengizinkan **Install unknown apps** dan
  menyetujui installer. Aplikasi tidak dapat memasang update secara diam-diam.
- Update nyata sudah diverifikasi owner pada I2505/Android 16. Perangkat
  Android 8–15 tetap perlu diuji saat tersedia.
- `latest.json` hanya dibuat untuk release stabil; draft/prerelease diabaikan
  oleh updater.
- Bulk insert bersifat atomik: satu baris invalid menggagalkan seluruh batch
  lokal/server. Belum ada retry per baris; outbox gagal terlihat di status sync.
- Migration `20261114140000_bulk_debt_insert.sql` sudah diterapkan dan
  `admin-sync` versi 4 aktif di remote. Verifikasi perangkat masih pending.

## PIN reset runbook (operator)

Tidak ada endpoint reset PIN di aplikasi. Prosedur ini hanya untuk operator
dengan akses SQL/service-role. Jangan membagikan hash, token, atau secret.

1. Cabut semua sesi admin aktif:

   ```sql
   update public.admin_sessions
   set revoked_at = now()
   where revoked_at is null;
   ```

2. Kembalikan PIN ke status belum diinisialisasi:

   ```sql
   update public.admin_settings
   set pin_hash = repeat('0', 64),
       pin_hash_algorithm = 'uninitialized',
       pin_changed_at = null,
       failed_attempt_count = 0,
       locked_until = null
   where id = '00000000-0000-0000-0000-000000000001';
   ```

3. Set `ADMIN_INITIAL_PIN` sementara melalui secret server, login dari aplikasi
   untuk membuat PIN baru, lalu hapus secret tersebut.
4. Audit tindakan reset melalui log operator di luar aplikasi; jangan mencatat
   nilai PIN.

## Rollback dan pemulihan

- Backup JSON adalah pemulihan lokal, bukan disaster recovery cloud.
- Restore-merge tidak menghapus atau menimpa data yang sudah ada.
- Full destructive cloud restore di luar scope v1 dan memerlukan keputusan
  owner serta prosedur terpisah.
- Jangan menurunkan version code atau mengganti application ID pada update.
