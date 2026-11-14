# Sprint 10 — GitHub Release Automation

## Status

**Selesai pada 14 November 2026 — GitHub dry run dan rilis otomatis `v1.0.0`
berhasil dijalankan.** Plan ini mendefinisikan workflow, versioning, changelog,
dan prosedur rilis. Implementasi hanya menyentuh tooling, workflow, dan
dokumentasi; tidak ada fitur aplikasi yang berubah. Rilis `v1.0.1+2` dan
`v1.0.2+3` kemudian menerapkan kontrak `latest.json` dari Sprint 11.

Keputusan final owner:

1. Release dipicu manual lewat `workflow_dispatch`.
2. `main` dilindungi; release memakai `RELEASE_TOKEN`, bukan alur release PR.
3. Bump default `auto` dari conventional commits.
4. Rilis pertama adalah `v1.0.0` dari versi saat ini `1.0.0+1`.
5. Changelog dibuat dengan `git-cliff`.

## Goal

Membuat satu alur rilis GitHub Actions yang:

1. Menjalankan quality gate.
2. Menentukan versi berikutnya secara otomatis.
3. Memperbarui `pubspec.yaml` dan `CHANGELOG.md`.
4. Membangun APK release yang sudah ditandatangani.
5. Membuat commit rilis, tag Git, dan GitHub Release.
6. Mengunggah APK + checksum ke GitHub Release.

Rilis v1 tetap **APK-only**. AAB, Play Console, dan upload ke Play Store tidak
termasuk scope.

## Prinsip

- Versi dan changelog harus konsisten dengan APK yang diunggah.
- Build number selalu naik dan tidak pernah dipakai ulang.
- Release harus bisa diulang dengan aman; kegagalan build tidak boleh
  meninggalkan tag/release setengah jadi.
- Secret hanya berada di GitHub Secrets; tidak masuk repo, log, APK, atau
  artifact publik.
- Release otomatis dipicu secara eksplisit, bukan setiap push ke `main`, agar
  commit dokumentasi biasa tidak menjadi rilis.
- Changelog hanya berisi perubahan yang dipahami pengguna dan tidak memuat
  data sensitif.

## Kondisi saat ini

- Versi aplikasi: `1.0.0+1` di `pubspec.yaml`.
- APK release dibangun manual dengan:
  ```bash
  flutter build apk --release \
    --dart-define-from-file=config/app_config.local.json
  ```
- Signing memakai `android/key.properties` dan keystore di luar repo.
- CI yang ada: `.github/workflows/ci.yml` untuk format, analyze, Flutter test,
  pgTAP, lint database, dan Deno test.
- Belum ada Git tag, `CHANGELOG.md`, atau workflow release.
- Deployment Supabase dilakukan terpisah dari rilis APK dan tidak perlu
  dijalankan ulang pada setiap release aplikasi, kecuali ada migration/function
  baru.

## Keputusan owner

| Topik | Keputusan |
|---|---|
| Trigger | `workflow_dispatch` manual |
| Bump default | `auto` dari conventional commits, fallback `patch` |
| Bump manual | `patch`, `minor`, `major`, `build-only`, `initial` |
| Format versi | SemVer `MAJOR.MINOR.PATCH+BUILD` |
| Tag | `vMAJOR.MINOR.PATCH` |
| Changelog | `CHANGELOG.md` format Keep a Changelog |
| Generator changelog | `git-cliff` + `cliff.toml` |
| Commit rilis | `chore(release): vX.Y.Z+B` |
| APK asset | `debt-reminder-vX.Y.Z+B.apk` |
| Checksum | `debt-reminder-vX.Y.Z+B.apk.sha256` |
| Push ke main | `RELEASE_TOKEN` wajib karena `main` dilindungi |
| Rilis pertama | `v1.0.0`, memakai `1.0.0+1` |
| Dry run | Input `dry_run=true`, tidak commit/tag/release |

Trigger manual dipilih karena “release” adalah keputusan produk. Otomatisasi
tetap terjadi setelah trigger: bump, changelog, build, tag, dan release.

### Konsekuensi `main` dilindungi

Workflow tidak dapat memakai `GITHUB_TOKEN` default untuk push commit/tag ke
`main`. Implementasi wajib memakai `RELEASE_TOKEN`:

- Fine-grained PAT atau GitHub App token.
- Izin minimal `Contents: write`; `Metadata: read`; `Actions: read`.
- Token disimpan sebagai GitHub Secret `RELEASE_TOKEN`.
- Akun/bot pemilik token harus diizinkan melewati ruleset `main`, atau ruleset
  harus memiliki bypass khusus untuk release bot.
- Token harus dirotasi dan tidak boleh dipakai untuk keperluan lain.

Jika bypass belum dikonfigurasi, workflow harus berhenti sebelum commit/tag dan
tidak meninggalkan release setengah jadi.

## Versioning

`pubspec.yaml` tetap menjadi satu-satunya sumber versi:

```yaml
version: 1.2.3+7
```

Arti:

- `1.2.3` = version name.
- `7` = build number/version code Android.
- Build number wajib naik pada setiap APK yang didistribusikan, termasuk rebuild
  dengan version name yang sama.
- Build number tidak boleh diturunkan atau dipakai ulang.

Aturan bump:

| Mode | Version name | Build |
|---|---|---|
| `patch` | `1.2.3` → `1.2.4` | +1 |
| `minor` | `1.2.3` → `1.3.0` | +1 |
| `major` | `1.2.3` → `2.0.0` | +1 |
| `build-only` | Tetap | +1 |
| `initial` | Pakai versi saat ini | Tetap pada build saat ini |
| `auto` | Berdasarkan commit sejak tag terakhir | +1 |

`auto` membaca conventional commits:

- `feat:` → minor
- `fix:`, `perf:`, `security:` → patch
- `feat!:` atau `BREAKING CHANGE:` → major
- Selain itu → patch
- Jika tidak ada commit yang layak dirilis → gagal dengan pesan jelas, bukan
  membuat rilis kosong.

Contoh setelah `v1.0.0`:

```text
hanya fix:       1.0.0+1 → 1.0.1+2
ada feat:        1.0.0+1 → 1.1.0+2
breaking change: 1.0.0+1 → 2.0.0+2
build-only:      1.0.0+1 → 1.0.0+2
```

`initial` hanya boleh dipakai untuk rilis pertama. Syaratnya:

- belum ada tag `v*`,
- `pubspec.yaml` masih `1.0.0+1`,
- `CHANGELOG.md` belum memiliki bagian rilis final.

Rilis pertama menghasilkan:

```text
pubspec.yaml  version: 1.0.0+1
tag           v1.0.0
release       Debt Reminder v1.0.0 (build 1)
```

Setelah itu semua release wajib memakai `auto` atau bump manual yang menaikkan
build number.

## Changelog

Format `CHANGELOG.md`:

```markdown
# Changelog

## [Unreleased]

## [1.2.3] - 2026-11-14

### Added
- ...

### Changed
- ...

### Fixed
- ...

### Security
- ...
```

Aturan:

- Bagian rilis baru ditempatkan tepat di bawah `## [Unreleased]`.
- Changelog dibuat dari commit sejak tag terakhir.
- Commit `chore(release): ...` tidak dimasukkan.
- Commit internal yang tidak relevan dapat dikelompokkan ke `Changed`.
- Jangan menulis secret, token, PIN, alamat pribadi, atau data bisnis.
- Release notes GitHub memakai isi bagian versi terbaru dari changelog.
- `CHANGELOG.md` dibuat pada implementasi, bukan oleh setiap build developer.

Konfigurasi `cliff.toml`:

- Tag pattern: `v[0-9]*`.
- Conventional commit parser untuk `feat`, `fix`, `perf`, `security`, `refactor`,
  `docs`, `test`, `build`, `ci`, dan `chore`.
- Group output:
  - `feat` → `Added`
  - `fix`/`perf` → `Fixed`
  - `security` → `Security`
  - `refactor`/`docs`/`test`/`build`/`ci`/`chore` → `Changed`
- Commit `chore(release)` di-skip.
- Changelog writer memakai format Keep a Changelog.
- Release body memakai rendered changelog untuk tag tersebut.

Untuk rilis pertama `initial`, `git-cliff` dijalankan dengan tag `v1.0.0` dan
mengambil seluruh commit yang belum masuk changelog final.

## Workflow yang direncanakan

File baru: `.github/workflows/release.yml`.

### Trigger

```yaml
on:
  workflow_dispatch:
    inputs:
      bump:
        description: "auto | patch | minor | major | build-only | initial"
        required: true
        default: auto
      dry_run:
        description: "Build tanpa commit/tag/release"
        type: boolean
        default: false
      prerelease:
        description: "Tandai GitHub Release sebagai prerelease"
        type: boolean
        default: false
```

Tidak memakai trigger `push` ke `main`. Release hanya dijalankan lewat
`workflow_dispatch` agar commit dokumentasi biasa tidak otomatis menjadi rilis.

`build-only` hanya diizinkan dengan `dry_run=true`, karena tag/version yang sama
tidak boleh dipublikasikan ulang. Untuk rilis nyata gunakan `auto`, `patch`,
`minor`, atau `major`.

### Concurrency

```yaml
concurrency:
  group: release
  cancel-in-progress: false
```

Hanya satu release boleh berjalan. Release kedua menunggu, bukan membatalkan
build yang sedang berjalan.

### Permissions

Minimal:

```yaml
permissions:
  contents: write
  actions: read
```

Karena `main` dilindungi, `GITHUB_TOKEN` default tidak dipakai untuk push.
Workflow wajib memakai `RELEASE_TOKEN` (fine-grained PAT/GitHub App token)
dengan izin `Contents: write`, `Metadata: read`, dan `Actions: read`. Akun/bot
pemilik token harus masuk bypass ruleset `main`. Jangan memakai PAT milik akun
luas dan jangan memakai `GITHUB_TOKEN` untuk memaksa push.

### Jobs

#### 1. `prepare`

- Checkout `main` dengan `fetch-depth: 0`.
- Pastikan working tree bersih.
- Pastikan tidak ada release lain yang sedang berjalan.
- Setup Flutter `3.47.7`, Java 21, dan Android SDK platform 37/build-tools 36.
- Jalankan quality gate:
  - `dart format --output=none --set-exit-if-changed .`
  - `flutter analyze`
  - `flutter test`
- Tentukan versi berikutnya dengan `tool/release/next_version.dart`.
- Generate section changelog dengan `git-cliff` (`--strip header`) lalu
  menyisipkannya setelah `## [Unreleased]`.
- Jalankan `dart format` pada file yang berubah bila diperlukan.
- Simpan versi dan changelog sebagai artifact workflow.

Quality gate backend (pgTAP/Deno) tetap dijalankan oleh CI terpisah. Release
tidak perlu menunggu job backend bila tidak ada perubahan schema/function.
Jika ada perubahan backend, release harus menunggu CI backend hijau.

#### 2. `build`

- Buat `android/key.properties` dari secrets di `$RUNNER_TEMP`.
- Decode keystore base64 ke `$RUNNER_TEMP/upload-keystore.jks`.
- Build:
  ```bash
  flutter build apk --release \
    --dart-define=APP_ENV=production \
    --dart-define=SUPABASE_URL="$SUPABASE_URL" \
    --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
    --dart-define=SEED_DEMO_DATA=false
  ```
- Verifikasi:
  - `aapt dump badging`: package, version name, version code.
  - `apksigner verify --print-certs`.
  - `android.permission.INTERNET` ada.
  - URL Supabase remote tertanam.
- Hitung SHA-256.
- Simpan APK dan checksum sebagai artifact.

Release ini **tidak** membuat AAB dan tidak mengunggah ke Play Console.

#### 3. `publish`

- Jika `dry_run=true`: berhenti setelah artifact/verifikasi.
- Commit `pubspec.yaml` dan `CHANGELOG.md`:
  ```text
  chore(release): vX.Y.Z+B
  ```
- Push commit ke `main` memakai `RELEASE_TOKEN` yang diizinkan bypass ruleset.
- Pastikan ruleset `main` mengizinkan release bot; jika tidak, gagal sebelum
  tag dibuat.
- Buat annotated tag `vX.Y.Z`.
- Push tag memakai `RELEASE_TOKEN`.
- Buat GitHub Release:
  - title: `Debt Reminder vX.Y.Z (build B)`
  - body: changelog versi terbaru
  - assets: APK dan `.sha256`
  - `prerelease` mengikuti input.
- Jika release/tag sudah ada, workflow harus idempotent: verifikasi aset lalu
  berhenti, bukan menimpa tag yang sudah published.

## Secret yang dibutuhkan

| Secret | Fungsi |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | Isi keystore yang di-encode base64 |
| `ANDROID_STORE_PASSWORD` | Password keystore |
| `ANDROID_KEY_ALIAS` | Alias key |
| `ANDROID_KEY_PASSWORD` | Password key |
| `SUPABASE_URL` | URL project Supabase |
| `SUPABASE_ANON_KEY` | Anon/publishable key |
| `RELEASE_TOKEN` | Wajib; push commit/tag ke `main` yang dilindungi |

Tidak boleh ada:

- `SUPABASE_SERVICE_ROLE_KEY`
- `ADMIN_PIN_PEPPER`
- `ADMIN_SESSION_JWT_SECRET`
- PIN admin
- Isi `key.properties` atau keystore di repo/log/artifact publik

Anon key memang dapat dibaca publik, tetapi tetap disimpan sebagai secret agar
tidak tersebar di source dan artifact build log.

## File yang akan dibuat/diubah saat implementasi

Hanya workflow/tooling/dokumentasi, bukan fitur aplikasi:

- `.github/workflows/release.yml` — workflow release.
- `tool/release/next_version.dart` — bump SemVer + build number.
- `tool/release/verify_apk.sh` — verifikasi package, versi, permission, signature.
- `test/tool/next_version_test.dart` — unit test version bumper.
- `cliff.toml` — konfigurasi changelog.
- `CHANGELOG.md` — changelog awal.
- `plans/sprints/SPRINT_10_RELEASE_AUTOMATION.md` — plan ini.
- `README.md` — cara release.
- `plans/RELEASE_CHECKLIST.md` — gate release otomatis.
- `plans/STATUS.md` — status implementasi setelah selesai.

Tidak ada perubahan pada `lib/`, `android/app/src/main`, Supabase, atau fitur
aplikasi.

## Cara release

### Persiapan awal

1. Buat GitHub Secrets:
   - `ANDROID_KEYSTORE_BASE64`
   - `ANDROID_STORE_PASSWORD`
   - `ANDROID_KEY_ALIAS`
   - `ANDROID_KEY_PASSWORD`
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `RELEASE_TOKEN`
2. Buat fine-grained PAT/GitHub App token untuk `RELEASE_TOKEN`:
   - `Contents: write`
   - `Metadata: read`
   - `Actions: read`
3. Tambahkan akun/bot pemilik token ke bypass ruleset `main`, termasuk izin
   push commit dan tag. Tanpa ini workflow akan berhenti sebelum commit.
4. Pastikan `main` memiliki CI hijau.
5. Pastikan keystore upload valid dan password-nya tersimpan aman. Jangan
   mencetak isi secret ke log.
6. Jalankan dry run pertama:
   ```bash
   gh workflow run release.yml -f bump=initial -f dry_run=true
   gh run watch
   ```
7. Periksa artifact APK dry run: versi `1.0.0+1`, signature, isi changelog, dan
   tidak ada tag/release baru.

### Rilis pertama `v1.0.0`

1. Pastikan belum ada tag `v*`:
   ```bash
   git tag --list 'v*'
   ```
2. Jalankan:
   ```bash
   gh workflow run release.yml -f bump=initial
   gh run watch
   ```
3. Workflow membuat:
   - commit `chore(release): v1.0.0+1`,
   - tag `v1.0.0`,
   - GitHub Release `Debt Reminder v1.0.0 (build 1)`,
   - asset APK dan checksum.
4. Verifikasi:
   ```bash
   gh release view v1.0.0
   gh release download v1.0.0 --pattern '*.apk'
   sha256sum -c debt-reminder-v1.0.0+1.apk.sha256
   ```

### Release rutin

1. Merge perubahan ke `main`.
2. Pastikan CI hijau.
3. Jalankan:
   ```bash
   gh workflow run release.yml -f bump=auto
   gh run watch
   ```
4. `auto` menentukan patch/minor/major dari conventional commits sejak tag
   terakhir:
   - `fix` → patch, misalnya `1.0.1+2`
   - `feat` → minor, misalnya `1.1.0+2`
   - breaking change → major, misalnya `2.0.0+2`

   `build-only` hanya untuk dry run karena akan memakai tag/version yang sama:
   ```bash
   gh workflow run release.yml -f bump=build-only -f dry_run=true
   ```
5. Override manual bila perlu:
   ```bash
   gh workflow run release.yml -f bump=patch
   gh workflow run release.yml -f bump=minor
   gh workflow run release.yml -f bump=major
   gh workflow run release.yml -f bump=build-only
   ```
6. Workflow akan bump versi, membuat changelog, build APK, verifikasi
   signature, commit + tag, lalu publish GitHub Release.
7. Verifikasi:
   ```bash
   gh release view vX.Y.Z
   gh release download vX.Y.Z --pattern '*.apk'
   sha256sum -c debt-reminder-vX.Y.Z+B.apk.sha256
   ```
8. Install APK ke I2505, jalankan smoke test, lalu distribusikan.

### Jika release gagal

- Sebelum commit/tag: perbaiki penyebab dan jalankan ulang; tidak ada tag yang
  berubah.
- Setelah commit tetapi sebelum tag: jalankan ulang publish; commit harus
  idempotent dan tidak membuat duplikat.
- Setelah tag published: **jangan pindahkan tag**. Buat patch release baru
  dengan build number berikutnya.
- Jangan menghapus release/tag yang sudah dibagikan kecuali ada keputusan owner
  dan belum ada pengguna yang mengunduh.
- Jika `RELEASE_TOKEN` tidak dapat bypass `main`, workflow harus berhenti
  sebelum commit/tag dan menampilkan error yang jelas.

## Acceptance criteria

- `workflow_dispatch` dengan `dry_run=true` tidak mengubah repo/tag/release.
- Rilis pertama menghasilkan tepat `v1.0.0` dari `1.0.0+1`.
- Release berikutnya menaikkan version name sesuai conventional commits dan
  selalu menaikkan build number.
- `CHANGELOG.md` dan GitHub Release notes berisi perubahan sejak tag terakhir.
- APK release ditandatangani, lolos `apksigner`, dan berisi:
  - package `com.debtreminder.app`,
  - version sesuai `pubspec.yaml`,
  - `android.permission.INTERNET`,
  - konfigurasi Supabase remote.
- APK dan checksum tersedia sebagai asset GitHub Release.
- Release gagal tidak meninggalkan tag/release setengah jadi.
- `RELEASE_TOKEN` dapat push commit/tag ke `main` yang dilindungi tanpa
  menonaktifkan ruleset.
- Tidak ada secret di log, artifact, APK, atau repo.
- AAB/Play Console tidak dibuat.
- Setelah release, APK dapat di-install dan diuji di I2505.

## Test plan

- Unit test untuk `next_version.dart`: patch/minor/major/build-only/initial,
  validasi build number, dan penolakan versi mundur.
- Test dry-run workflow pada branch sebelum release nyata.
- Verifikasi changelog dari commit `feat`, `fix`, dan breaking change.
- Verifikasi kegagalan test/build tidak membuat tag.
- Verifikasi dua release berurutan menghasilkan version code berbeda.
- Verifikasi APK asset dan checksum dapat diunduh dari GitHub Release.
- Smoke test APK hasil workflow di I2505: install, public pull, login admin,
  reminder publik, dan hard delete/backup.

## Risks / operational notes

1. **Branch protection:** `RELEASE_TOKEN` harus memiliki bypass ruleset `main`.
   Token ini setara dengan akses tulis repo; simpan hanya di GitHub Secrets,
   rotasi berkala, dan jangan pakai untuk keperluan lain.
2. **Conventional commits:** `auto` bergantung pada format commit. Commit saat
   ini belum semuanya conventional; fallback `patch` harus aman, dan tim perlu
   membiasakan format `feat:`, `fix:`, `feat!:`, atau `BREAKING CHANGE:`.
3. **Backend deploy:** migration/function Supabase tetap manual atau workflow
   terpisah; release APK tidak otomatis mengubah cloud.
4. **Keystore:** kehilangan keystore/password berarti tidak bisa update dengan
   signing identity yang sama. Backup keystore dan password di luar repo.
5. **GitHub runner:** Android SDK 37 dan build-tools 36 harus dipasang eksplisit
   di workflow, bukan mengandalkan image runner.
6. **First release:** `initial` hanya boleh sekali. Setelah `v1.0.0` dibuat,
   workflow harus menolak `initial` kembali dan mewajibkan bump berikutnya.
7. **Changelog:** commit lama sebelum implementasi belum mengikuti conventional
   commits; changelog pertama perlu ditinjau manual agar tidak berisi noise.

## Langkah implementasi

1. Tambahkan `tool/release/next_version.dart` dan unit test-nya.
2. Tambahkan `cliff.toml`, `CHANGELOG.md`, dan verifikasi output changelog.
3. Tambahkan `.github/workflows/release.yml` dengan input `bump`, `dry_run`,
   `prerelease`, concurrency, dan quality gate.
4. Tambahkan signing/config Supabase dari GitHub Secrets.
5. Tambahkan build, verifikasi APK, checksum, commit/tag, dan GitHub Release.
6. Uji dry run di branch sebelum rilis nyata.
7. Buat rilis pertama `v1.0.0` dan verifikasi asset APK.
8. Uji release kedua dengan `auto` untuk memastikan build number naik.
9. Perbarui `README.md`, `plans/RELEASE_CHECKLIST.md`, dan `plans/STATUS.md`.

## Out of scope

- AAB dan Play Console.
- Upload otomatis ke Play Store.
- Deploy Supabase otomatis.
- Release notes berbahasa otomatis dari AI.
- Code signing selain Android APK.
- Perubahan fitur aplikasi.
