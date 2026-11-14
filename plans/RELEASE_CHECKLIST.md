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
- Status: seluruh checklist owner-reported passed
- Distribusi: APK bertanda tangan langsung; AAB/Play Console tidak dipakai

## Wajib sebelum rilis

- [x] `dart format --output=none --set-exit-if-changed .` bersih.
- [x] `flutter analyze` tanpa issue.
- [x] `flutter test` seluruh suite lulus.
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

## Checklist perangkat fisik

- [x] Fresh install APK release berhasil; tidak ada data lama.
- [x] Splash menampilkan logo dan nama **Debt Reminder** tanpa terpotong.
- [x] Icon launcher tampil benar (legacy dan adaptive).
- [x] Drawer, dashboard, daftar hutang, detail hutang, dan pengaturan terbuka.
- [x] Public read berhasil tanpa login; tombol mutasi tidak tampil.
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
