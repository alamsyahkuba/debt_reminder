# Product Requirements

## 1. Roles

### Publik
- Tidak perlu login.
- Dapat melihat seluruh data bisnis: group, hutang, pembayaran, dan status.
- Read-only.
- Tidak dapat membuat, mengedit, menghapus, atau mengarsipkan data.
- Tidak dapat membuka fitur admin tanpa PIN.
- Tidak memerlukan enrollment perangkat.
- Tidak dapat mengakses data admin, audit, sesi, atau internal metadata.

### Admin tunggal
- Membuka Drawer → Admin → memasukkan PIN.
- Mengelola group, hutang, dan pembayaran.
- Mengubah pengaturan reminder.
- Melakukan operasi saat offline; perubahan masuk antrean sinkronisasi.
- Sesi admin memiliki expiry dan dapat dikunci/logout.
- Semua mutasi cloud diverifikasi server-side.

### Owner
- Pemilik perangkat/aplikasi dan penanggung jawab konfigurasi.
- Pada versi pertama owner dan admin dapat merupakan orang yang sama.
- Tidak ada role owner kedua atau multi-admin dalam scope.

## 2. Functional requirements

### Dashboard
- Menampilkan total nominal hutang awal.
- Menampilkan total pembayaran.
- Menampilkan total sisa hutang.
- Menampilkan jumlah hutang aktif, lunas, dan overdue.
- Menampilkan ringkasan per group.
- Menampilkan hutang yang mendekati jatuh tempo.
- Semua angka dihitung dari data lokal yang konsisten.
- Publik dapat melihat dashboard yang sama tanpa aksi mutasi.

### Debt groups
- Create, edit, archive, restore, dan delete sesuai aturan.
- Group memiliki nama, deskripsi opsional, warna, ikon, sort order, timestamps.
- Group sederhana; tidak memiliki `parent_id` atau subgroup.
- Filter daftar hutang berdasarkan group.
- Group detail menampilkan jumlah hutang, total awal, pembayaran, dan sisa.
- Hutang dapat dipindahkan antar-group.
- Hutang tanpa group boleh ada (Unassigned).
- Group yang memiliki hutang tidak boleh dihapus tanpa konfirmasi dan strategi
  relasi yang jelas; default: pindahkan hutang menjadi Unassigned.
- Archived group tidak muncul di daftar aktif, tetapi histori hutangnya tetap
  tersedia.

### Debts
- Create, edit, archive/soft-delete.
- Field minimum: id, group_id nullable, title, principal_amount, due_date
  nullable, notes nullable, created_at, updated_at, version.
- Tidak ada `customer_id`.
- Identitas peminjam, bila diperlukan, ditulis di judul atau catatan hutang.
- Status ditentukan dari pembayaran dan tanggal:
  - unpaid: paid amount = 0 dan belum overdue
  - partial: 0 < paid amount < principal
  - paid: paid amount >= principal (validasi mencegah overpayment atau
    kebijakan eksplisit)
  - overdue: unpaid/partial dan due date sudah lewat
- Status jangan menjadi sumber kebenaran terpisah jika dapat dihitung.
- Publik dapat melihat seluruh field hutang.

### Payments
- Create payment/cicilan.
- Histori pembayaran append-only.
- Field: id, debt_id, amount, paid_at, notes nullable, operation_id/idempotency
  key, created_at.
- Validasi amount > 0.
- Kebijakan overpayment: default ditolak; jika dibutuhkan, harus menjadi
  keputusan owner.
- Pembayaran tidak dihapus/diubah biasa; koreksi melalui reversal/adjustment
  yang tercatat (fitur adjustment dapat ditunda).
- Publik dapat melihat seluruh field pembayaran.

### Search & filtering
- Search judul hutang dan catatan.
- Filter group, status, due date.
- Sort by due date, newest, amount, group.
- Search tetap bekerja offline.
- Tidak ada pencarian pelanggan.

### Reminders
- Admin dapat memilih reminder H-3, H-1, dan hari H (configurable).
- Reminder lokal pada perangkat.
- Jadwal ulang ketika due date/status berubah.
- Cancel reminder saat debt lunas atau archived.
- Reminder tidak boleh menganggap notifikasi sebagai bukti pembayaran.
- Publik hanya melihat informasi jatuh tempo; konfigurasi reminder milik admin.

### Settings
- Admin PIN change.
- Reminder preferences.
- Sync status/manual sync.
- Lock admin session.
- App info dan privacy note.
- Tidak ada pengaturan perangkat read-only.

## 3. Non-functional requirements

- UI tidak menunggu network untuk menampilkan data lokal.
- Error offline ditampilkan secara jelas, bukan crash.
- Sync retry aman dan idempotent.
- Data admin/sensitif tidak ditulis ke log.
- Supabase secrets tidak berada di source Flutter.
- Public read hanya melalui RPC/view read-only; anon tidak memiliki akses tulis.
- Accessibility: text readable, touch targets nyaman, kontras memadai.
- Currency formatting IDR konsisten.
- Tanggal/timezone menggunakan timezone lokal perangkat dengan penyimpanan
  timestamp yang konsisten.
