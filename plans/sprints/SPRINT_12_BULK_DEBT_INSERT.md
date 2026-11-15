# Sprint 12 — Bulk Insert Hutang

Status: Diimplementasikan dan dideploy; test Flutter, Deno, pgTAP, dan deploy
cloud berhasil. Verifikasi perangkat masih pending.
Tanggal: 14 November 2026.
Dependency: Sprint 11 selesai. Owner sudah menyetujui lima keputusan Sprint 12.
Plan ini menambah satu RPC server atomik dan operasi Edge Function
`debt_batch`; tidak mengubah tabel bisnis, RLS, public RPC, atau format backup.

## 1. Tujuan

Memungkinkan admin menambahkan beberapa hutang sekaligus dalam satu layar dan
satu transaksi lokal, tanpa mengetik satu per satu melalui form hutang biasa.

Hasil yang diharapkan:

- Admin memasukkan nama dasar, jumlah angsuran (1–50), dan nominal per
  angsuran; aplikasi membuat hutang otomatis berjudul `Nama 1`, `Nama 2`, dst.
- Semua hutang hasil generate masuk database lokal dan outbox dalam satu
  transaksi atomik.
- Jika data batch tidak valid, tidak ada hutang yang tersimpan (all-or-nothing
  secara lokal).
- Data tetap offline-first: hutang langsung terlihat dan tetap pending sampai
  sync admin berhasil.
- Publik tidak memiliki akses ke layar atau aksi bulk insert.
- Tabel bisnis, RLS, public read RPC, dan format backup tidak berubah.
- Server menerima satu operasi `debt_batch` atomik untuk seluruh batch.

## 2. Keputusan owner

| Topik | Keputusan |
|---|---|
| Metode input | Generator angsuran otomatis: nama dasar + jumlah angsuran + nominal per angsuran |
| Judul hutang | `Nama 1`, `Nama 2`, dst. (angka increment setelah judul) |
| Import CSV/Excel | Ditunda ke fase berikutnya; tidak termasuk MVP |
| Group | Satu group untuk seluruh batch, dipilih di header |
| Jatuh tempo | Default batch opsional; checklist per bulan menambah 1 bulan per angsuran |
| Batas batch | Maksimal 50 hutang per transaksi |
| Penyimpanan | Satu transaksi SQLite; satu outbox `debt_batch` per batch |
| Sync server | Satu RPC atomik `admin_bulk_create_debts` |
| Server bulk RPC | Ya; seluruh batch commit atau rollback bersama |
| Duplikat | Tidak ada dedupe otomatis; judul/nominal/tanggal boleh sama |
| Edit hasil generate | Setiap hutang dapat diedit judul/nominal/tanggal/catatan sebelum disimpan |
| Konfirmasi | Dialog konfirmasi jika jumlah angsuran > 1 |
| Undo batch | Tidak termasuk MVP |

Server memakai registry idempotency yang sama dengan operasi lain. Satu
`operation_id` mewakili seluruh batch, sehingga retry tidak menduplikasi
hutang.

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

Layar **Bulk Insert Hutang**:

1. **Data angsuran**
   - `Nama hutang` — nama dasar, wajib.
   - `Jumlah angsuran` — angka 1–50.
   - `Pokok per angsuran` — nominal rupiah yang sama untuk setiap hutang.
   - Dropdown **Group untuk semua hutang** (termasuk Unassigned).
   - `Jatuh tempo default (opsional)`.
   - Checklist **Jatuh tempo per bulan**.
   - `Catatan (opsional)` yang sama untuk semua hutang.

2. **Pratinjau otomatis dan dapat diedit**
   - Judul dibuat dengan format `Nama 1`, `Nama 2`, hingga `Nama N`.
   - Setiap baris pratinjau menampilkan judul, nominal, dan jatuh tempo.
   - Setiap baris memiliki aksi **Edit** untuk mengubah judul, pokok, jatuh
     tempo, dan catatan.
   - Perubahan header hanya memengaruhi baris yang belum diedit; baris yang
     sudah diedit mempertahankan nilainya.
   - Total nominal ditampilkan di bawah daftar.

3. **Aksi simpan**
   - Tombol **Simpan N hutang** di bagian bawah.
   - Jika N > 1, tampilkan dialog konfirmasi.
   - Saat menyimpan: tombol disabled, label `Menyimpan...`, tidak ada double
     submit.
   - Sukses: kembali ke daftar hutang dan tampilkan SnackBar
     `N hutang ditambahkan dan menunggu sinkronisasi.`
   - Gagal validasi: tetap di layar dan tandai field yang salah.
   - Gagal database: tampilkan error, tidak ada hutang yang tersimpan.

### 3.3 Perilaku group dan tanggal

- Group di header berlaku untuk semua angsuran. Untuk group berbeda, simpan
  batch lain.
- Jatuh tempo default diterapkan ke seluruh angsuran yang di-generate.
- Jika **Jatuh tempo per bulan** aktif: angsuran 1 = default, angsuran 2 = +1
  bulan, angsuran 3 = +2 bulan, dst.
- Tanggal akhir bulan di-clamp, misalnya 31 Januari + 1 bulan = 28/29 Februari.
- Tanggal disimpan sebagai tanggal UTC tanpa waktu, mengikuti
  `normalizeDueDate`.
- Rentang date picker: 2000–2100.

### 3.4 Batas dan pesan

- Jumlah angsuran 1–50.
- Judul hasil generate maksimal 200 karakter; nama dasar dibatasi agar suffix
  angka tetap muat.
- Catatan maksimal 2000 karakter.
- Nominal harus integer rupiah positif dan tidak melebihi `maxSafeRupiah`.
- Jika group sudah dihapus saat layar masih terbuka, simpan ditolak dengan
  pesan `Group tidak ditemukan. Pilih group lain.` dan input tetap utuh.

## 4. Model dan repository

### 4.1 Value object domain

Tambahkan entity domain ringan, tanpa dependensi Flutter/Drift/Supabase:

```dart
const int maxDebtBatchSize = 50;

final class DebtDraft {
  const DebtDraft({
    required this.title,
    required this.principalAmount,
    this.dueDate,
    this.notes,
  });

  final String title;
  final int principalAmount;
  final DateTime? dueDate;
  final String? notes;
}
```

Group berada di parameter batch `createMany`, bukan di setiap draft. Ini
mengikuti keputusan owner: satu group per batch.

### 4.2 Kontrak repository

Method berikut ditambahkan ke `DebtRepository`:

```dart
Future<List<Debt>> createMany({
  String? groupId,
  required List<DebtDraft> drafts,
});
```

Aturan implementasi:

1. Tolak daftar kosong dan daftar lebih dari 50 item.
2. Validasi seluruh draft sebelum menulis apa pun:
   - judul memakai `validateText(maxLength: 200)`;
   - nominal memakai `validatePositiveRupiah`;
   - catatan memakai `validateOptionalText(maxLength: 2000)`;
   - tanggal memakai `normalizeDueDate`;
   - group batch harus ada di tabel `debt_groups` jika tidak null.
3. Buka satu `_db.transaction`.
4. Gunakan satu timestamp `now` untuk seluruh batch.
5. Buat ID untuk setiap hutang, satu batch ID, dan satu operation ID.
6. Upsert semua baris hutang dan enqueue satu operasi `debt_batch`/`create`
   dengan payload `{id: batchId, debts: [...]}` di dalam transaksi yang sama.
7. Kembalikan `List<Debt>` sesuai urutan input.
8. Jika satu langkah gagal, transaksi rollback: tidak ada hutang maupun outbox
   yang tersisa.

Outbox per baris tidak dibuat. Dengan demikian satu kegagalan server tidak
meninggalkan sebagian batch tersinkron.

### 4.3 Sync server atomik

Owner memilih satu RPC atomik, sehingga implementasi memakai:

- Edge Function `admin-sync` menerima `entity_type='debt_batch'`,
  `operation='create'`.
- Validasi handler: 1–50 baris, setiap baris memakai field hutang yang diizinkan,
  tidak ada ID duplikat, nominal/tanggal/group valid.
- RPC `public.admin_bulk_create_debts(operation_id, entity_id, payload, ...)`
  memakai `begin_operation`/`complete_operation`, insert semua hutang dalam satu
  statement, menulis audit `sync.batch_create`, lalu commit.
- Jika satu baris gagal (constraint, group hilang, ID duplikat), seluruh
  transaksi rollback dan operation tidak tercatat sebagai sukses.
- Retry dengan operation ID dan payload hash yang sama mengembalikan respons
  sebelumnya tanpa duplikasi.
- Worker lokal memproses group sebelum `debt_batch`, dan `debt_batch` sebelum
  payment yang mereferensikan hutang baru. Setelah sukses, semua baris lokal
  ditandai `synced` dari daftar hasil server.

Batas 50 dipilih agar satu batch muat dalam satu operasi dan payload tetap
terkendali. Tidak ada endpoint bulk tambahan di luar RPC tersebut.

## 5. UI state dan implementasi Flutter

### 5.1 File baru

- `lib/domain/entities/debt_draft.dart`
- `lib/features/debts/presentation/bulk_debt_form_screen.dart`
- `supabase/migrations/20261114140000_bulk_debt_insert.sql`
- `supabase/tests/admin_bulk_debt.test.sql`
- `test/features/bulk_debt_flow_test.dart`
- `test/data/repositories/bulk_debt_test.dart`
- `test/data/sync/bulk_debt_sync_test.dart`

### 5.2 File yang diubah

- `lib/domain/repositories/debt_repository.dart`
- `lib/data/repositories/debt_repository_impl.dart`
- `lib/data/repositories/outbox_payloads.dart`
- `lib/data/remote/admin_sync_repository.dart`
- `lib/data/sync/admin_sync_service.dart`
- `lib/domain/entities/admin_mutation_result.dart`
- `lib/features/debts/presentation/debts_screen.dart`
- `lib/app/navigation.dart`
- `lib/app/router.dart`
- `supabase/functions/admin-sync/handler.ts`
- `supabase/functions/admin-sync/handler_test.ts`
- `supabase/functions/admin-sync/index.ts`
- `plans/STATUS.md`, `README.md`, `plans/05_UI_UX_SPEC.md`, dan
  `supabase/README.md` setelah implementasi

Tidak ada perubahan:

- `lib/data/local/app_database.dart`
- migration Drift
- tabel dan constraint bisnis Supabase
- RLS dan `public_*` RPC
- model payment/group

### 5.3 Pengelolaan state form

- Layar memakai `ConsumerStatefulWidget`.
- State menyimpan controller nama dasar, jumlah angsuran, nominal per
  angsuran, catatan, group, tanggal default, dan checklist per bulan.
- Daftar default dihitung dari state tersebut, dengan judul `Nama 1..N`.
- Edit per baris disimpan sebagai override per indeks; default hanya dipakai
  untuk baris yang belum diedit.
- Saat jumlah angsuran turun, override di luar jumlah baru dibuang.
- Daftar `DebtDraft` final dibentuk dari default + override saat preview/save.
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
| Nama kosong | Tidak ada yang disimpan; error field |
| Jumlah angsuran 0/>50 | Tidak ada yang disimpan; error field |
| Judul hasil generate >200 karakter | Error nama; tidak ada yang disimpan |
| Nominal nol/negatif/overflow | Error field; tidak ada yang disimpan |
| Catatan terlalu panjang | Error field; tidak ada yang disimpan |
| Group tidak ada | Error; input tetap di layar |
| Double tap simpan | Dicegah dengan state `_saving` |
| Database penuh/error tulis | Transaksi rollback; error jelas |
| Offline | Batch tersimpan lokal, outbox pending |
| Sesi admin expired saat sync | Outbox dipertahankan; minta login ulang |
| Satu baris gagal di server | Seluruh batch rollback; tidak ada baris server yang tersimpan |
| App ditutup saat menyimpan | SQLite rollback atau commit utuh, tidak parsial |
| Batch > 50 | Validasi field dan repository menolak |

## 8. Test plan

### 8.1 Repository

- `createMany` menyimpan N hutang dan satu outbox `debt_batch` dalam satu
  transaksi.
- Semua hutang memakai timestamp batch yang konsisten dan group yang benar.
- Batch ID dan operation ID stabil setelah retry.
- Satu baris invalid membatalkan seluruh hutang dan outbox.
- Group yang tidak ada membatalkan seluruh batch.
- Daftar kosong dan lebih dari 50 ditolak.
- Baris dengan catatan/tanggal kosong dinormalisasi dengan benar.
- Data langsung terlihat melalui `watchOverviews`.
- Backup/export memuat hutang hasil bulk.

### 8.2 Sync

- Satu batch menghasilkan satu operasi `debt_batch`/`create`.
- Retry dengan operation ID yang sama tidak menduplikasi hutang di server.
- Satu baris invalid membuat seluruh batch server rollback.
- Kegagalan batch tidak menghapus hutang lokal atau outbox.
- Outbox bertahan setelah database ditutup dan dibuka kembali.
- Batch diproses setelah group dan sebelum payment.

### 8.3 Widget

- Admin melihat tombol **Tambah Banyak**; publik tidak.
- Route `/debts/bulk` tanpa sesi diarahkan ke PIN dan kembali setelah unlock.
- Input nama, jumlah angsuran, dan nominal menghasilkan pratinjau
  `Nama 1..N`.
- Total nominal pratinjau dihitung benar.
- Edit satu baris mengubah judul/nominal/tanggal/catatan pada pratinjau dan
  hasil simpan; baris lain tetap memakai default.
- Jumlah angsuran 1, 5, dan 50 menghasilkan jumlah judul yang tepat.
- Jatuh tempo default otomatis diterapkan; checklist per bulan menghasilkan
  angsuran 1 = default, angsuran 2 = +1 bulan, dst.
- Nama terlalu panjang, jumlah angsuran invalid, dan nominal invalid ditolak.
- Simpan tiga angsuran menutup layar, menampilkan SnackBar, dan daftar hutang
  menampilkan tiga hutang.
- Dialog konfirmasi muncul untuk lebih dari satu angsuran.
- Tombol disabled saat menyimpan.
- Error group hilang menampilkan pesan dan mempertahankan input.

### 8.4 Integration/device

- Offline: buat batch → pending → reconnect → sync → restart → data tetap ada.
- Reminder untuk hutang baru dijadwalkan setelah batch masuk.
- Dashboard dan group summary bertambah sesuai total nominal batch.
- Uji 1, 5, dan 50 angsuran pada perangkat fisik.
- Uji keyboard, scroll, rotasi, dan kembali tanpa kehilangan input.
- Uji sesi admin expired saat batch masih pending.

## 9. Acceptance criteria

- [x] Admin dapat membuka **Tambah Banyak Hutang** dari layar Semua Hutang.
- [x] Publik tidak melihat tombol dan tidak dapat membuka route.
- [x] Admin dapat memasukkan 1–50 angsuran dan aplikasi menghasilkan judul
      `Nama 1..N`.
- [x] Nominal per angsuran diterapkan ke semua hutang hasil generate.
- [x] Group batch dan jatuh tempo default bekerja otomatis; checklist per
      bulan menambah 1 bulan per angsuran.
- [x] Nama, jumlah angsuran, nominal, catatan, dan panjang judul divalidasi.
- [x] Setiap hutang hasil generate dapat diedit sebelum disimpan.
- [x] Satu transaksi menyimpan semua hutang dan satu outbox batch.
- [x] Tidak ada data parsial jika validasi/transaksi gagal.
- [x] Hutang baru langsung terlihat di daftar; dashboard/group summary memakai
      stream lokal yang sama.
- [x] Seluruh batch sync lewat satu operasi atomik dengan operation ID stabil.
- [x] RPC server menolak batch invalid secara atomik dan replay tidak menduplikasi.
- [x] Tidak ada perubahan pada tabel bisnis, RLS, public RPC, atau service role.
- [x] `dart format`, `flutter analyze`, seluruh Flutter test, Deno test, dan
      pgTAP lulus.
- [x] Deploy migration dan Edge Function ke Supabase cloud.
- [ ] Uji offline → reconnect → restart dan reminder untuk batch pada perangkat
      fisik.

## 10. Di luar scope

- Import file CSV/Excel dan file picker.
- Paste dari clipboard/spreadsheet (dapat menjadi fase berikutnya).
- Bulk edit, bulk archive, bulk delete, atau bulk payment.
- Undo satu batch.
- Deteksi/merge duplikat otomatis.
- Progress upload per angsuran di UI; status tetap memakai sync status global.
- Perubahan pada customer (tidak ada customer) atau device enrollment.

RPC bulk insert sudah termasuk dalam scope Sprint 12, bukan di luar scope.

## 11. Keputusan owner (resolved)

1. **Metode input:** generator angsuran otomatis (nama dasar + jumlah
   angsuran + nominal per angsuran), bukan input baris manual.
2. **Batas batch:** maksimal 50 angsuran.
3. **Group:** satu group per batch.
4. **Sync:** server bulk RPC atomik.
5. **Konfirmasi:** dialog untuk batch lebih dari satu angsuran.

Import spreadsheet tetap ditunda.

## 12. Status implementasi

Selesai dan tervalidasi:

- [x] Domain `DebtDraft` dan `createMany` dengan batas 50.
- [x] Transaksi lokal atomik dan satu outbox `debt_batch`.
- [x] Edge Function `debt_batch` + validasi 1–50 baris/ID unik.
- [x] RPC `admin_bulk_create_debts` dengan idempotency, atomic insert, audit.
- [x] Dependency sync group → debt_batch → payment.
- [x] UI generator angsuran, pratinjau `Nama 1..N` yang dapat diedit, group
      batch, tanggal default otomatis, checklist per bulan, validasi, dan
      konfirmasi.
- [x] Route admin-only `/debts/bulk` dan tombol **Tambah Banyak**.
- [x] Test repository, sync, widget, handler Deno, dan pgTAP.
- [x] Format, analyze, seluruh Flutter test, Deno test, dan pgTAP lulus.
- [x] `flutter build apk --debug` lulus.
- [x] Deploy migration `20261114140000_bulk_debt_insert.sql` ke remote.
- [x] Deploy Edge Function `admin-sync` versi 4 ke remote.

Pending:

- [ ] Uji 1, 5, dan 50 angsuran pada perangkat fisik.
- [ ] Uji offline → reconnect → sync → restart dan reminder batch.
- [ ] Verifikasi dashboard/group summary pada perangkat.
