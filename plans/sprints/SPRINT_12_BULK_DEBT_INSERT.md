# Sprint 12 — Bulk Insert Hutang

Status: Draft — menunggu persetujuan owner; belum diimplementasikan.
Tanggal: 14 November 2026.
Dependency: Sprint 11 selesai (owner-reported device verification passed);
Sprint 12 tetap menunggu persetujuan owner sebelum coding. Plan ini tidak
mengubah schema lokal, Supabase, RLS, atau Edge Function.

## 1. Tujuan

Memungkinkan admin menambahkan beberapa hutang sekaligus dalam satu layar dan
satu transaksi lokal, tanpa mengetik satu per satu melalui form hutang biasa.

Hasil yang diharapkan:

- Admin dapat mengisi 1–50 baris hutang, lalu menyimpan semuanya sekaligus.
- Semua baris masuk database lokal dan outbox dalam satu transaksi atomik.
- Jika satu baris tidak valid, tidak ada baris yang tersimpan (all-or-nothing
  secara lokal).
- Data tetap offline-first: baris langsung terlihat dan tetap pending sampai
  sync admin berhasil.
- Publik tidak memiliki akses ke layar atau aksi bulk insert.
- Tidak ada perubahan pada data bisnis, schema, RLS, public RPC, atau format
  backup.

## 2. Keputusan yang diusulkan

| Topik | Rekomendasi |
|---|---|
| Metode input MVP | Form multi-baris manual di dalam aplikasi |
| Import CSV/Excel | Ditunda ke fase berikutnya; tidak termasuk MVP |
| Group | Satu group untuk seluruh batch, dipilih di header |
| Jatuh tempo | Default batch opsional; setiap baris dapat override |
| Batas batch | Maksimal 50 hutang per transaksi |
| Penyimpanan | Satu transaksi SQLite; satu outbox `debt/create` per hutang |
| Sync server | Tetap memakai operasi `debt/create` yang sudah ada |
| Server bulk RPC | Tidak diperlukan pada MVP |
| Duplikat | Tidak ada dedupe otomatis; judul/nominal/tanggal boleh sama |
| Konfirmasi | Dialog konfirmasi jika jumlah baris > 1 |
| Undo batch | Tidak termasuk MVP |

Keputusan ini menjaga perubahan tetap kecil: tidak ada migration, tidak ada
endpoint baru, dan mekanisme idempotency/version/audit yang sudah ada tetap
dipakai.

## 3. UX yang diusulkan

### 3.1 Entry point

Di layar **Semua Hutang**, tambahkan tombol admin-only **Tambah Banyak** di
dekat judul daftar hutang. FAB **Tambah Hutang** yang sekarang tetap dipakai
untuk input satu hutang.

- Tombol disembunyikan untuk publik.
- Route baru: `/debts/bulk`.
- Route masuk daftar admin-only di `_isAdminOnlyPath`, sehingga akses langsung
  tanpa sesi diarahkan ke PIN lalu kembali ke layar bulk.
- Tidak menambah menu baru di drawer.

### 3.2 Struktur layar

Layar **Tambah Banyak Hutang**:

1. **Header batch**
   - Dropdown **Group untuk semua hutang** (termasuk Unassigned).
   - Pilihan **Jatuh tempo default (opsional)**.
   - Tombol **Terapkan ke semua baris** untuk mengisi tanggal yang masih kosong.
   - Info: `0/50 hutang`.

2. **Daftar baris**
   - Setiap baris berupa card ringkas:
     - `Judul hutang` — wajib, maksimal 200 karakter.
     - `Pokok hutang` — wajib, angka rupiah positif.
     - `Jatuh tempo` — opsional; mengoverride default batch.
     - `Catatan` — opsional, maksimal 2000 karakter.
     - Tombol hapus baris.
   - Tombol **Tambah baris** di bawah daftar.
   - Baris baru otomatis fokus ke kolom judul.
   - Baris kosong di bagian bawah diabaikan saat submit.
   - Baris yang terisi sebagian (misalnya nominal tanpa judul) dianggap tidak
     valid dan harus diperbaiki.

3. **Aksi simpan**
   - Tombol **Simpan N hutang** di bagian bawah.
   - Jika N > 1, tampilkan dialog konfirmasi berisi jumlah dan group.
   - Saat menyimpan: tombol disabled, label `Menyimpan...`, tidak ada double
     submit.
   - Sukses: kembali ke daftar hutang dan tampilkan SnackBar
     `N hutang ditambahkan dan menunggu sinkronisasi.`
   - Gagal validasi: tetap di layar, tandai baris yang salah, scroll ke baris
     pertama yang gagal.
   - Gagal database: tampilkan error, tidak ada baris yang tersimpan.

### 3.3 Perilaku group dan tanggal

- Group di header berlaku untuk semua baris. Untuk menambah hutang ke group
  berbeda, admin menyimpan batch lain.
- Jatuh tempo default hanya dipakai jika baris belum memiliki tanggal.
- Mengubah default tidak menimpa tanggal yang sudah diisi manual.
- Tanggal disimpan sebagai tanggal UTC tanpa waktu, mengikuti
  `normalizeDueDate` yang sudah ada.
- Rentang date picker mengikuti form hutang saat ini: 2000–2100.

### 3.4 Batas dan pesan

- Minimal 1 baris berisi data.
- Maksimal 50 baris per batch.
- Judul 1–200 karakter.
- Catatan maksimal 2000 karakter.
- Nominal harus integer rupiah positif dan tidak melebihi `maxSafeRupiah`.
- Error menyebut nomor baris, misalnya
  `Baris 3: Pokok hutang harus berupa angka positif.`
- Jika group sudah dihapus saat layar masih terbuka, simpan ditolak dengan
  pesan `Group tidak ditemukan. Pilih group lain.` dan semua baris tetap utuh.

## 4. Model dan repository

### 4.1 Value object domain

Tambahkan entity domain ringan, tanpa dependensi Flutter/Drift/Supabase:

```dart
final class DebtDraft {
  const DebtDraft({
    required this.groupId,
    required this.title,
    required this.principalAmount,
    required this.dueDate,
    required this.notes,
  });

  final String? groupId;
  final String title;
  final int principalAmount;
  final DateTime? dueDate;
  final String? notes;
}
```

`groupId` tetap per draft agar fase import berikutnya dapat memakai group
berbeda per baris, walaupun UI MVP memakai satu group untuk seluruh batch.

### 4.2 Kontrak repository

Tambahkan method berikut ke `DebtRepository`:

```dart
Future<List<Debt>> createMany(List<DebtDraft> drafts);
```

Aturan implementasi:

1. Tolak daftar kosong dan daftar lebih dari 50 item.
2. Validasi seluruh draft sebelum menulis apa pun:
   - judul memakai `validateText(maxLength: 200)`;
   - nominal memakai `validatePositiveRupiah`;
   - catatan memakai `validateOptionalText(maxLength: 2000)`;
   - tanggal memakai `normalizeDueDate`;
   - semua `groupId` unik harus ada di tabel `debt_groups`.
3. Buka satu `_db.transaction`.
4. Gunakan satu timestamp `now` untuk seluruh batch.
5. Buat ID hutang dan operation ID baru untuk setiap baris.
6. Upsert semua baris hutang dan enqueue satu operasi `debt/create` per baris
   di dalam transaksi yang sama.
7. Kembalikan `List<Debt>` sesuai urutan input.
8. Jika satu langkah gagal, transaksi rollback: tidak ada hutang maupun outbox
   yang tersisa.

Outbox payload tetap memakai `debtCreatePayload` yang sudah ada. Tidak ada
perubahan format payload server.

### 4.3 Kenapa bukan satu operasi server bulk

MVP memakai satu operasi `debt/create` per hutang karena:

- kompatibel dengan `admin-sync`, idempotency registry, audit, dan conflict
  handling yang sudah ada;
- tidak perlu migration atau RPC baru;
- kegagalan satu baris tidak membatalkan baris lain yang sudah berhasil di
  server;
- batch lokal tetap atomic dari sudut pandang pengguna.

Konsekuensi yang harus disepakati:

- Sync server tidak atomic per batch. Jika satu baris ditolak server, baris lain
  tetap tersinkron dan baris yang gagal tetap ada secara lokal.
- Batch 50 baris dapat membutuhkan beberapa request berurutan. Worker sync
  default memproses maksimal 50 operasi per run, jadi batas 50 dipilih agar
  batch MVP muat dalam satu run.
- Jika performa sync 50 request dirasa terlalu lambat, operasi server
  `debt.bulk_create` dapat direncanakan sebagai optimasi terpisah. Itu bukan
  bagian Sprint 12.

## 5. UI state dan implementasi Flutter

### 5.1 File baru

- `lib/domain/entities/debt_draft.dart`
- `lib/features/debts/presentation/bulk_debt_form_screen.dart`
- `lib/features/debts/presentation/widgets/bulk_debt_row_editor.dart`
- `test/features/bulk_debt_flow_test.dart`
- `test/data/repositories/bulk_debt_test.dart`
- `test/data/sync/bulk_debt_sync_test.dart`

### 5.2 File yang diubah

- `lib/domain/repositories/debt_repository.dart`
- `lib/data/repositories/debt_repository_impl.dart`
- `lib/features/debts/presentation/debts_screen.dart`
- `lib/app/navigation.dart`
- `lib/app/router.dart`
- `plans/STATUS.md` setelah implementasi
- `README.md` dan `plans/05_UI_UX_SPEC.md` setelah implementasi

Tidak ada perubahan:

- `lib/data/local/app_database.dart`
- migration Drift
- migration Supabase
- `supabase/functions/admin-sync`
- `public_*` RPC
- model payment/group

### 5.3 Pengelolaan state form

- Layar memakai `ConsumerStatefulWidget`.
- Setiap baris memiliki model UI sendiri yang menyimpan controller judul,
  nominal, catatan, dan tanggal.
- Controller di-dispose saat baris dihapus dan saat layar ditutup.
- Perubahan teks tidak boleh membangun ulang seluruh daftar 50 baris; gunakan
  widget baris stateful atau listener lokal.
- Group dan tanggal default disimpan di state header.
- Validasi bisnis tetap dilakukan lagi di repository; validasi UI hanya untuk
  feedback cepat.

## 6. Reminder, dashboard, dan backup

Tidak ada perubahan khusus:

- `debtOverviewsProvider(false)` yang di-listen `ReminderLifecycle` akan
  menerima satu event stream setelah batch tersimpan, lalu menjadwalkan ulang
  reminder.
- Dashboard, group summary, pencarian, dan filter membaca database lokal dan
  langsung menampilkan baris baru.
- Backup/export otomatis memuat hutang baru karena membaca tabel `debts`.
- Public pull tidak berubah dan tidak boleh membuat outbox.

## 7. Penanganan kegagalan

| Kasus | Perilaku |
|---|---|
| Tidak ada baris berisi data | Tombol simpan disabled/validasi |
| Baris terisi sebagian | Tidak ada yang disimpan; error per baris |
| Judul terlalu panjang | Error baris; tidak ada yang disimpan |
| Nominal nol/negatif/overflow | Error baris; tidak ada yang disimpan |
| Catatan terlalu panjang | Error baris; tidak ada yang disimpan |
| Group tidak ada | Error; semua baris tetap di layar |
| Double tap simpan | Dicegah dengan state `_saving` |
| Database penuh/error tulis | Transaksi rollback; error jelas |
| Offline | Batch tersimpan lokal, outbox pending |
| Sesi admin expired saat sync | Outbox dipertahankan; minta login ulang |
| Satu baris gagal di server | Baris lain tetap sync; baris gagal muncul di sync status |
| App ditutup saat menyimpan | SQLite rollback atau commit utuh, tidak parsial |
| Batch > 50 | Tombol tambah baris disabled dan validasi repository |

## 8. Test plan

### 8.1 Repository

- `createMany` menyimpan N hutang dan N outbox dalam satu transaksi.
- Semua hutang memakai timestamp batch yang konsisten dan group yang benar.
- Operation ID setiap outbox unik dan stabil setelah retry.
- Satu baris invalid membatalkan seluruh hutang dan outbox.
- Group yang tidak ada membatalkan seluruh batch.
- Daftar kosong dan lebih dari 50 ditolak.
- Baris dengan catatan/tanggal kosong dinormalisasi dengan benar.
- Data langsung terlihat melalui `watchOverviews`.
- Backup/export memuat hutang hasil bulk.

### 8.2 Sync

- Tiga hutang hasil bulk menghasilkan tiga operasi `debt/create` yang dikirim
  berurutan.
- Retry tidak menduplikasi hutang di server.
- Satu operasi gagal tidak menghapus baris atau outbox lain.
- Outbox bertahan setelah database ditutup dan dibuka kembali.

### 8.3 Widget

- Admin melihat tombol **Tambah Banyak**; publik tidak.
- Route `/debts/bulk` tanpa sesi diarahkan ke PIN dan kembali setelah unlock.
- Tambah/hapus baris bekerja dan batas 50 ditegakkan.
- Baris kosong di bagian bawah diabaikan.
- Baris terisi sebagian menampilkan error dan tidak menyimpan.
- Default group dan tanggal diterapkan ke baris.
- Override tanggal per baris tidak tertimpa default.
- Simpan tiga baris menutup layar, menampilkan SnackBar, dan daftar hutang
  menampilkan tiga baris.
- Dialog konfirmasi muncul untuk lebih dari satu baris.
- Tombol disabled saat menyimpan.
- Error group hilang menampilkan pesan dan mempertahankan input.

### 8.4 Integration/device

- Offline: buat batch → pending → reconnect → sync → restart → data tetap ada.
- Reminder untuk hutang baru dijadwalkan setelah batch masuk.
- Dashboard dan group summary bertambah sesuai nominal batch.
- Uji 1, 5, dan 50 baris pada perangkat fisik.
- Uji keyboard, scroll, rotasi, dan kembali tanpa kehilangan input.
- Uji sesi admin expired saat batch masih pending.

## 9. Acceptance criteria

- [ ] Admin dapat membuka **Tambah Banyak Hutang** dari layar Semua Hutang.
- [ ] Publik tidak melihat tombol dan tidak dapat membuka route.
- [ ] Admin dapat menambah, menghapus, dan mengisi hingga 50 baris.
- [ ] Group batch dan jatuh tempo default bekerja; override per baris bekerja.
- [ ] Baris kosong diabaikan; baris terisi sebagian ditolak.
- [ ] Satu transaksi menyimpan semua hutang dan semua outbox.
- [ ] Tidak ada data parsial jika validasi/transaksi gagal.
- [ ] Hutang baru langsung terlihat di daftar, dashboard, dan group summary.
- [ ] Setiap hutang sync tepat sekali dengan operation ID stabil.
- [ ] Offline, retry, restart, dan auth failure mempertahankan outbox.
- [ ] Reminder mempertimbangkan hutang baru tanpa perubahan schema.
- [ ] Tidak ada perubahan pada RLS, public RPC, schema, atau service role.
- [ ] `dart format`, `flutter analyze`, dan seluruh test lulus.

## 10. Di luar scope

- Import file CSV/Excel dan file picker.
- Paste dari clipboard/spreadsheet (dapat menjadi fase berikutnya).
- Bulk edit, bulk archive, bulk delete, atau bulk payment.
- Undo satu batch.
- Deteksi/merge duplikat otomatis.
- Server RPC bulk insert.
- Progress upload per baris di UI; status tetap memakai sync status global.
- Perubahan pada customer (tidak ada customer) atau device enrollment.

## 11. Keputusan yang perlu disetujui owner

1. **Metode input MVP:** form multi-baris manual (rekomendasi) atau langsung
   tambahkan paste/import spreadsheet?
2. **Batas batch:** 50 (rekomendasi) atau 100?
3. **Group:** satu group per batch (rekomendasi) atau dropdown group per baris?
4. **Sync:** operasi per hutang yang sudah ada (rekomendasi) atau server bulk
   RPC atomic?
5. **Konfirmasi:** dialog untuk batch > 1 (rekomendasi) atau langsung simpan?

Jika owner memilih import spreadsheet, plan ini perlu ditambah parser,
preview, format kolom, dan test parsing sebelum implementasi dimulai.

## 12. Urutan implementasi

1. Tambahkan `DebtDraft` dan method `createMany` pada kontrak repository.
2. Implementasikan `createMany` atomik + outbox per hutang dan test repository.
3. Tambahkan route `/debts/bulk`, guard admin, dan tombol entry point.
4. Bangun layar bulk, row editor, group/date default, serta validasi UI.
5. Tambahkan dialog konfirmasi, SnackBar, dan state loading/error.
6. Tambahkan test widget dan sync untuk batch.
7. Jalankan format/analyze/test, lalu uji offline → reconnect → restart dan
   reminder pada perangkat fisik.
8. Perbarui `STATUS.md`, README, dan UI spec setelah implementasi disetujui.
