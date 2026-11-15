# UI/UX Specification

## 1. Navigation

Drawer:
- Dashboard
- Semua Hutang
- Group Hutang
- Reminder
- Pengaturan
- Admin (PIN gate)

Menu Pelanggan dihapus.

Admin menu membuka PIN screen. Setelah unlock, aksi mutasi terlihat. Lock/logout
kembali ke mode publik/read-only.

## 2. Mode akses

### Mode publik
- Tanpa login.
- Semua data bisnis terlihat.
- Tidak ada tombol create/edit/archive/delete.
- Data berasal dari cache lokal dan public pull.

### Mode admin
- Dibuka setelah PIN valid.
- Aksi CRUD group, hutang, dan pembayaran terlihat.
- Aksi mutation lokal masuk outbox.
- Session expiry/lock mengembalikan UI ke mode publik.

## 3. Screens

### Dashboard
- Summary cards: principal, paid, outstanding.
- Counts: active, partial, overdue, paid.
- Group summary.
- Upcoming due debts.
- Sync indicator.
- Banner update di bagian atas jika cek otomatis menemukan build lebih baru;
  tombol **Lihat Update** membuka Pengaturan.

### Group list
- Active groups ordered by `sort_order`.
- Group color/icon.
- Debt count and outstanding sum.
- Create group button (admin only).
- Archived groups accessible from separate filter.

### Group detail
- Group metadata.
- Summary totals.
- Debt list filtered to group.
- Search/sort/filter.
- Admin actions: edit/archive/reorder/delete/move debt.

### All debts
- Search field untuk judul/catatan.
- Filters: group, payment status, overdue, due date.
- Sort: due date, latest, outstanding amount, group.
- Debt row shows title, group, due date, remaining amount, status.
- Tidak ada kolom customer.
- Admin-only **Bulk Insert Hutang** memakai generator angsuran: nama dasar,
  jumlah angsuran 1–50, nominal per angsuran, satu group batch, catatan
  opsional, tanggal default, dan checklist **jatuh tempo per bulan** (angsuran
  1 = default, berikutnya +1 bulan). Pratinjau menampilkan judul `Nama 1..N`,
  nominal, tanggal, dan total; dialog konfirmasi muncul untuk batch >1.
- Bulk insert memakai satu transaksi lokal dan satu RPC server atomik; publik
  tidak dapat melihat tombol atau membuka route.

### Debt detail
- Principal amount.
- Paid total and outstanding amount.
- Due date and notes.
- Payment history.
- Admin: edit, record payment, move group, archive, dan hard delete hanya jika
  belum ada payment.
- Tidak ada informasi customer.

### Payment form
- Amount, paid_at, notes.
- Tombol **Bayar Lunas** mengisi/membuat pembayaran sebesar seluruh sisa
  hutang setelah konfirmasi.
- Validate positive amount and no overpayment by default.
- Confirmation before saving.
- Show offline/pending-sync status.
- Admin only.

### Admin PIN
- Secure input 6 digit; PIN tidak pernah ditampilkan atau dicatat.
- Verifikasi dilakukan server; offline unlock tidak tersedia.
- Rate-limit feedback (5 percobaan gagal, lock 15 menit).
- Error generic enough not to expose internals.
- Session expiry 15 menit, lock manual, dan perubahan PIN.
- Sesi aktif membuka aksi mutasi; tanpa sesi aplikasi bersifat read-only.

### Settings
- Reminder schedule (device-local; dapat diakses publik dan admin).
- Admin PIN change (tanpa recovery UI).
- Sync now.
- Backup/export JSON dan restore-merge admin-only.
- Pending operations and last sync.
- App version dan privacy note.
- Tidak ada menu perangkat read-only.

### Reminder
- Publik dan admin dapat mengaktifkan H-3, H-1, dan/atau H serta memilih waktu
  lokal.
- Tampilkan status izin notifikasi dan exact alarm beserta fallback-nya.
- Tampilkan jadwal pengingat mendatang.
- Tidak ada kontrol mutasi bisnis di halaman ini; preferensi reminder hanya
  disimpan di perangkat.
- Notifikasi bukan bukti pembayaran.

## 4. Visual rules
- Material 3.
- Responsive to small Android screens.
- Currency format `Rp 1.000.000` (locale Indonesia).
- Clear status colors with text labels; color alone is not sufficient.
- Loading, empty, error, offline, dan pending-sync states untuk setiap data
  screen.
- Confirm destructive/archive actions.
- No subgroup UI.
- Public mode tidak menampilkan aksi mutation.

### Backup/export
- Admin memilih export JSON berisi group, hutang, dan pembayaran.
- File dibagikan melalui share sheet/file picker.
- Restore-merge menampilkan preview, validasi referensi, dan tidak menimpa data
  yang sudah ada.
- Export disarankan sebelum hard delete.
