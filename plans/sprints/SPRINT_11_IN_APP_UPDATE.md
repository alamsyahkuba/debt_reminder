# Sprint 11 — In-App Update

Status: implementasi kode dan test otomatis selesai; rilis uji dan verifikasi
perangkat masih pending.
Tanggal: 14 November 2026.
Scope: tombol cek update, download APK dari GitHub Release, verifikasi, dan
membuka installer Android.

## 1. Tujuan

Menambahkan alur di dalam aplikasi:

1. Pengguna menekan **Cek Update**.
2. Aplikasi memeriksa GitHub Release terbaru.
3. Jika ada versi lebih baru, aplikasi menampilkan versi, ukuran, dan catatan
   rilis.
4. Pengguna menekan **Download & Pasang**.
5. APK diunduh, checksum diverifikasi, lalu sistem installer Android dibuka.
6. Setelah pengguna menyetujui instalasi, aplikasi diperbarui tanpa kehilangan
   data lokal.

“Otomatis install” berarti aplikasi otomatis mengunduh dan membuka installer.
Android tetap mewajibkan konfirmasi pengguna; aplikasi biasa tidak boleh
memasang APK secara diam-diam.

## 2. Distribusi publik — sudah diputuskan

Repo `alamsyahkuba/debt_reminder` sudah dijadikan **public**. Keputusan:

- GitHub API dan asset Release dapat diakses tanpa token.
- Aplikasi **tidak** menyimpan GitHub token.
- Tidak perlu repo release terpisah.
- Source code, migration, dan dokumentasi sekarang publik; pastikan tidak ada
  secret di source maupun riwayat Git.
- APK dan `latest.json` dipublikasikan langsung sebagai asset Release repo ini.

Endpoint update:

```text
https://api.github.com/repos/alamsyahkuba/debt_reminder/releases/latest
```

Workflow release tetap memakai `RELEASE_TOKEN` untuk push commit/tag dan
membuat Release, tetapi token tersebut tidak pernah dikirim ke aplikasi.

## 3. Kontrak release untuk updater

Setiap release harus memiliki asset:

```text
debt-reminder-vX.Y.Z+B.apk
debt-reminder-vX.Y.Z+B.apk.sha256
latest.json
```

`latest.json`:

```json
{
  "schema_version": 1,
  "version_name": "1.2.3",
  "build_number": 4,
  "tag": "v1.2.3",
  "apk_asset": "debt-reminder-v1.2.3+4.apk",
  "apk_sha256": "<hex sha256>",
  "apk_size_bytes": 71722598,
  "release_url": "https://github.com/alamsyahkuba/debt_reminder/releases/tag/v1.2.3",
  "published_at": "2026-11-14T08:00:00Z",
  "notes": "Perubahan penting..."
}
```

Aturan:

- `schema_version` wajib 1.
- `build_number` adalah pembanding utama update.
- `apk_sha256` wajib ada dan diverifikasi setelah download.
- `latest.json` hanya dibuat untuk release stabil/non-prerelease.
- Release draft dan prerelease diabaikan oleh updater.
- Asset APK harus memakai package `com.debtreminder.app` dan signing key yang
  sama dengan aplikasi terpasang.
- `notes` ditampilkan sebagai teks biasa; jangan render HTML mentah.

## 4. Alur pengecekan versi

Aplikasi:

1. Mengambil versi lokal via `package_info_plus`:
   - `versionName`
   - `buildNumber`
2. Memanggil:
   ```text
   GET https://api.github.com/repos/alamsyahkuba/debt_reminder/releases/latest
   ```
   Header:
   - `Accept: application/vnd.github+json`
   - `X-GitHub-Api-Version: 2022-11-28`
   - `User-Agent: Debt-Reminder/<version>`
3. Mencari asset `latest.json` pada release.
4. Mengunduh/membaca manifest.
5. Membandingkan `build_number` remote dengan build lokal.

Hasil:

| Kondisi | UI |
|---|---|
| remote build > lokal | update tersedia |
| remote build == lokal | sudah versi terbaru |
| remote build < lokal | tidak menawarkan downgrade |
| release prerelease/draft | diabaikan |
| manifest tidak ada/invalid | tampilkan error, jangan install |

GitHub API unauthenticated memiliki rate limit rendah (60 request/jam per IP).
Karena pengecekan manual, ini cukup. Jangan melakukan polling otomatis pada v1.

## 5. Download dan verifikasi

Urutan:

1. Validasi URL asset:
   - host `api.github.com`, `github.com`, atau `objects.githubusercontent.com`
   - HTTPS saja
2. Cek ruang penyimpanan.
3. Download streaming ke cache:
   ```text
   <cache>/updates/debt-reminder-vX.Y.Z+B.apk
   ```
4. Tampilkan progress berdasarkan `Content-Length`.
5. Hitung SHA-256 saat download.
6. Bandingkan dengan `apk_sha256` dari manifest.
7. Jika checksum salah:
   - hapus file,
   - tampilkan error,
   - jangan buka installer.
8. Verifikasi APK:
   - package name = `com.debtreminder.app`
   - version code = `build_number` manifest
   - sertifikat signing APK = sertifikat aplikasi terpasang
9. Buka installer Android.

Verifikasi package dan signature sebaiknya dilakukan di native Android karena
`package_info_plus` tidak menyediakan signature APK. Jangan hanya mengandalkan
checksum; checksum membuktikan integritas transfer, bukan identitas aplikasi.

## 6. Instalasi Android

### Manifest

Tambahkan:

```xml
<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>
```

Tambahkan FileProvider untuk file APK di cache:

```xml
<provider
  android:name="androidx.core.content.FileProvider"
  android:authorities="${applicationId}.fileprovider"
  android:exported="false"
  android:grantUriPermissions="true">
  <meta-data
    android:name="android.support.FILE_PROVIDER_PATHS"
    android:resource="@xml/file_paths"/>
</provider>
```

`file_paths.xml` hanya mengekspos folder update, bukan seluruh storage.

### Alur installer

Direkomendasikan custom MethodChannel minimal:

```text
com.debtreminder.app/installer
  canRequestPackageInstalls()
  openInstallPermissionSettings()
  verifyAndInstall(apkPath, expectedPackage, expectedVersionCode, certSha256)
```

Native Android:

1. Cek izin **Install unknown apps**.
2. Jika belum, buka:
   ```text
   Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES
   ```
3. Verifikasi APK dengan `PackageManager.getPackageArchiveInfo`.
4. Bandingkan signature dengan aplikasi saat ini.
5. Buat content URI via FileProvider.
6. Kirim intent `ACTION_VIEW` MIME `application/vnd.android.package-archive`,
   atau gunakan `PackageInstaller` untuk status yang lebih detail.
7. Pengguna tetap menekan tombol **Install** di sistem.

Alternatif plugin: `open_filex`/`install_plugin`. Namun keduanya tetap tidak
menyelesaikan verifikasi signature. Custom channel lebih terkontrol dan hanya
menambah sedikit kode Android.

## 7. Arsitektur Flutter

Tambahan dependency:

```text
package_info_plus     versi lokal/build
crypto                SHA-256
path_provider         cache update
```

`http` sudah ada. Jika memakai native channel, tidak perlu plugin installer
pihak ketiga.

Layer:

```text
domain/
  entities/app_update.dart
    AppUpdateInfo
    UpdateCheckResult
    DownloadProgress
  repositories/app_update_repository.dart

data/
  remote/github_release_repository.dart
  updates/app_update_service.dart
  updates/apk_installer_gateway.dart
  updates/installer_method_channel.dart

features/settings/
  application/app_update_providers.dart
  presentation/app_update_card.dart
```

Aturan:

- Widget tidak boleh memanggil GitHub langsung.
- Repository remote mengembalikan model domain.
- Service menangani download, checksum, cache cleanup, dan state.
- Installer gateway mengabstraksi MethodChannel agar dapat di-fake pada test.
- Jangan menaruh token GitHub di client.
- Jangan log URL file lokal dengan data sensitif; URL publik release boleh.

## 8. State UI

Di **Pengaturan → Pembaruan aplikasi**:

```text
Versi terpasang: 1.0.0 (build 1)
[ Cek Update ]
```

State:

- `idle`
- `checking`
- `upToDate`
- `updateAvailable(version, build, size, notes, releaseUrl)`
- `downloading(progressBytes, totalBytes)`
- `verifying`
- `readyToInstall`
- `installerOpened`
- `permissionRequired`
- `error(message)`

Tombol:

- **Cek Update** — manual, disabled saat checking/downloading.
- **Download & Pasang** — download, verifikasi, lalu buka installer.
- **Buka Pengaturan Izin** — jika unknown sources belum aktif.
- **Coba Lagi** — setelah error.
- **Lihat Rilis** — membuka release URL di browser (opsional).

Update card tersedia untuk publik dan admin karena tidak mengubah data bisnis.
Jangan menambahkan update kontrol ke mode publik yang sedang membaca data;
ini adalah operasi aplikasi, bukan operasi bisnis.

## 9. Release workflow yang harus disesuaikan

Workflow release yang ada (`SPRINT_10_RELEASE_AUTOMATION`) harus:

1. Membuat `latest.json` setelah APK dan checksum selesai.
2. Mengunggah tiga asset ke repo release publik:
   - APK
   - `.sha256`
   - `latest.json`
3. Memastikan release stabil ditandai non-prerelease.
4. Menyimpan `RELEASE_TOKEN` yang memiliki akses tulis ke repo public.
5. Tidak mengunggah token, keystore, atau service-role key.
6. Menjaga asset name stabil antar-rilis.

Upload ke repo public utama:

```bash
gh release create "$TAG" \
  "$APK" "$APK.sha256" latest.json \
  --repo alamsyahkuba/debt_reminder \
  --title "Debt Reminder $VERSION (build $BUILD)" \
  --notes-file release-notes.md
```

Tidak ada token di aplikasi; asset release dapat diunduh anonim karena repo
sudah public.

## 10. Keamanan

- HTTPS dan host allowlist.
- Checksum SHA-256 wajib.
- Verifikasi package name, version code, dan signing certificate.
- Tolak APK dengan signature berbeda.
- Jangan pernah install APK dari URL arbitrer yang diberikan pengguna.
- Jangan simpan GitHub token di aplikasi.
- Sanitasi release notes; plain text.
- Hapus APK lama dari cache setelah install/gagal.
- Jika update dibatalkan, file cache boleh dihapus.
- Jangan mengklaim update berhasil sampai sistem melaporkan instalasi selesai,
  atau tampilkan status “installer dibuka” jika memakai intent.
- `REQUEST_INSTALL_PACKAGES` adalah izin sensitif; hanya dipakai untuk APK yang
  telah diverifikasi.

## 11. Penanganan kegagalan

| Kasus | Perilaku |
|---|---|
| Offline | error jelas, tombol coba lagi |
| GitHub rate limit | pesan coba beberapa saat lagi |
| Manifest hilang/invalid | jangan install |
| Asset APK hilang | error, tidak mengubah data |
| Checksum salah | hapus file, error |
| Signature berbeda | tolak install |
| Penyimpanan penuh | error sebelum download |
| Unknown sources ditolak | buka pengaturan izin |
| User membatalkan installer | state kembali ke siap install |
| Koneksi putus saat download | hapus partial file, retry |
| Versi remote lebih rendah | tidak menawarkan downgrade |

## 12. Test plan

Unit:

- Parse `latest.json` valid/invalid.
- Pilih asset APK dan checksum.
- Bandingkan build number.
- Abaikan prerelease/draft.
- Tolak host URL di luar allowlist.
- SHA-256 file valid/salah.
- State machine controller.

Widget:

- Tombol cek update muncul.
- Checking state.
- Up-to-date state.
- Update available state.
- Download progress.
- Error/retry.
- Permission required.
- Public mode tetap dapat melihat update card.

Device I2505:

1. Install APK versi lama.
2. Publikasikan release versi baru di repo release publik.
3. Tekan Cek Update.
4. Download, verifikasi checksum, buka installer.
5. Setujui install; pastikan data lokal tetap ada.
6. Uji unknown sources ditolak.
7. Uji checksum rusak/signature mismatch untuk memastikan update ditolak.
8. Uji offline dan rate limit/error.
9. Uji update dari build lama ke build baru tanpa kehilangan database.

## 13. File yang akan diubah saat implementasi

- `pubspec.yaml`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/res/xml/file_paths.xml`
- `android/app/src/main/kotlin/com/debtreminder/app/installer/...`
- `lib/domain/entities/app_update.dart`
- `lib/domain/repositories/app_update_repository.dart`
- `lib/data/remote/github_release_repository.dart`
- `lib/data/updates/app_update_service.dart`
- `lib/data/updates/installer_gateway.dart`
- `lib/features/settings/application/app_update_providers.dart`
- `lib/features/settings/presentation/app_update_card.dart`
- `lib/features/settings/presentation/settings_screen.dart`
- `test/...`
- `plans/sprints/SPRINT_11_IN_APP_UPDATE.md`
- `.github/workflows/release.yml` untuk `latest.json` dan asset release publik
- `README.md`, `plans/RELEASE_CHECKLIST.md`, `plans/STATUS.md`

Tidak ada perubahan pada data bisnis, Supabase schema, RLS, atau reminder.

## 14. Urutan implementasi

1. Audit repo public untuk memastikan tidak ada secret di source maupun riwayat
   Git.
2. Tambahkan `latest.json` ke workflow release dan unggah ke repo public utama.
3. Implementasi model/repository/service update.
4. Implementasi native installer + FileProvider + izin.
5. Implementasi UI Settings dan state.
6. Tambahkan unit/widget test.
7. Build release baru dan publikasikan test release.
8. Uji update di I2505, termasuk signature/checksum negatif.
9. Perbarui dokumentasi dan release checklist.

## 15. Definition of done

- Tombol Cek Update tersedia di Pengaturan.
- Aplikasi membandingkan build lokal dengan release publik.
- Update tersedia ditampilkan dengan versi, ukuran, dan catatan.
- Download menampilkan progress dan dapat dibatalkan/retry.
- SHA-256 diverifikasi.
- Package, version code, dan signature diverifikasi sebelum install.
- Installer Android terbuka dan pengguna dapat menyelesaikan update.
- Data lokal, sesi admin, dan preferensi reminder tetap setelah update.
- Tidak ada token GitHub atau secret lain di APK.
- Updater menolak URL di luar allowlist dan koneksi non-HTTPS.
- Aplikasi tetap dapat dipakai jika pengecekan update gagal.

## 16. Keputusan

1. **Distribusi publik:** repo utama `alamsyahkuba/debt_reminder` sudah public.
   Updater memakai GitHub API dan asset Release publik tanpa token.
2. **Installer:** custom MethodChannel + verifikasi signature. Plugin installer
   pihak ketiga tidak dipakai.
3. **Visibilitas:** tombol update untuk publik dan admin.
4. **Cek otomatis:** manual saja untuk v1; tidak ada polling saat startup.
5. **Release notes:** teks polos dari `latest.json`.
6. **Minimum Android:** mengikuti minSdk existing (24).

## 17. Status implementasi

Selesai dan tervalidasi otomatis:

- [x] Model domain `AppUpdateInfo`, `AppVersionInfo`, dan state installer.
- [x] `GitHubReleaseRepository` membaca GitHub Release + `latest.json`,
      mengabaikan draft/prerelease, dan menolak URL selain HTTPS/GitHub.
- [x] `AppUpdateService` memeriksa ruang penyimpanan, mengunduh streaming,
      menampilkan progress, memverifikasi SHA-256 dan ukuran, mendukung
      pembatalan, serta membersihkan file gagal.
- [x] `AppUpdateController` menangani checking, available, up-to-date,
      downloading, permission, installer opened, dan error.
- [x] Kartu Settings menampilkan versi terpasang, Cek Update, Download & Pasang,
      progress, Batalkan, pengaturan izin, dan retry. Kartu tersedia untuk
      publik dan admin.
- [x] Native Android memverifikasi package, version code, dan sertifikat signing
      sebelum membuka installer melalui FileProvider.
- [x] Manifest memuat `REQUEST_INSTALL_PACKAGES` dan FileProvider hanya untuk
      folder cache `updates/`.
- [x] Workflow release membuat dan mengunggah `latest.json` bersama APK dan
      `.sha256`.
- [x] Test unit/widget untuk parsing manifest, keamanan URL, checksum,
      ruang penyimpanan, pembatalan, state controller, UI, dan akses publik.
- [x] `flutter analyze`, seluruh `flutter test`, actionlint, prettier, dan
      `flutter build apk --debug` lulus.

Belum selesai:

- [ ] Rilis GitHub stabil yang berisi APK + `.sha256` + `latest.json`. Release
      `v1.0.0` hanya berisi APK + `.sha256` karena dibuat sebelum perubahan
      workflow Sprint 11.
- [ ] Uji update nyata di I2505: build lama → build baru, data lokal tetap ada.
- [ ] Uji negatif di perangkat: checksum salah, signature mismatch, izin
      unknown sources ditolak, offline/rate limit.
- [ ] Uji installer pada rentang Android 8–16 sesuai perangkat yang tersedia.
- [x] Verifikasi ruleset `main` aktif dan `RELEASE_TOKEN` ada di bypass list.
