# Product Requirements

## 1. Roles

### User biasa
- Tidak perlu login.
- Perangkat read-only harus di-enroll oleh admin sebelum dapat menarik data
  cloud; enrollment bukan login user dan tidak memberikan akses admin.
- Dapat melihat data yang diizinkan, termasuk nama, telepon, catatan, hutang,
  group, dan histori pembayaran.
- Read-only.
- Tidak dapat membuat, mengedit, menghapus hutang, group, atau pembayaran.
- Tidak dapat membuka fitur admin tanpa PIN.
- Token perangkat dapat dicabut admin.

### Admin tunggal
- Membuka Drawer → Admin → memasukkan PIN.
- Mengelola group, pelanggan, hutang, dan pembayaran.
- Mengubah pengaturan reminder.
- Melakukan operasi saat offline; perubahan masuk antrean sinkronisasi.
- Sesi admin memiliki expiry dan dapat dikunci/logout.

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
- Semua angka dihitung dari data lokal yang konsisten.

### Debt groups
- Create, edit, archive, restore, dan delete sesuai aturan.
- Group memiliki nama, deskripsi opsional, warna, ikon, sort order, timestamps.
- Group sederhana; tidak memiliki `parent_id` atau subgroup.
- Filter daftar hutang berdasarkan group.
- Group detail menampilkan jumlah hutang, total awal, pembayaran, dan sisa.
- Hutang dapat dipindahkan antar-group.
- Hutang tanpa group boleh ada (Unassigned).
- Group yang memiliki hutang tidak boleh dihapus tanpa konfirmasi dan strategi relasi yang jelas; default: pindahkan hutang menjadi Unassigned.
- Archived group tidak muncul di daftar aktif, tetapi histori hutangnya tetap tersedia.

### Customers
- Create, edit, archive, search.
- Nama wajib; nomor telepon dan catatan opsional.
- Customer memiliki banyak debt.
- Jangan hard-delete customer yang memiliki histori hutang.

### Debts
- Create, edit, archive/soft-delete.
- Field minimum: id, customer_id, group_id nullable, title, principal_amount, due_date nullable, notes nullable, status derived/controlled, created_at, updated_at, version.
- Status ditentukan dari pembayaran dan tanggal:
  - unpaid: paid amount = 0 dan belum overdue
  - partial: 0 < paid amount < principal
  - paid: paid amount >= principal (validasi mencegah overpayment atau kebijakan eksplisit)
  - overdue: unpaid/partial dan due date sudah lewat
- Status jangan menjadi sumber kebenaran terpisah jika dapat dihitung.

### Payments
- Create payment/cicilan.
- Histori pembayaran append-only.
- Field: id, debt_id, amount, paid_at, notes nullable, operation_id/idempotency key, created_at.
- Validasi amount > 0.
- Kebijakan overpayment: default ditolak; jika dibutuhkan, harus menjadi keputusan owner.
- Pembayaran tidak dihapus/diubah biasa; koreksi melalui reversal/adjustment yang tercatat (fitur adjustment dapat ditunda).

### Search & filtering
- Search customer name, debt title, dan notes bila relevan.
- Filter group, status, due date.
- Sort by due date, newest, amount, customer.
- Search tetap bekerja offline.

### Reminders
- Admin dapat memilih reminder H-3, H-1, dan hari H (configurable).
- Reminder lokal pada perangkat.
- Jadwal ulang ketika due date/status berubah.
- Cancel reminder saat debt lunas atau archived.
- Reminder tidak boleh menganggap notifikasi sebagai bukti pembayaran.

### Settings
- Admin PIN change.
- Reminder preferences.
- Sync status/manual sync.
- Lock admin session.
- Kelola perangkat read-only: enroll, lihat status, dan cabut akses.
- App info dan privacy note.

## 3. Non-functional requirements
- UI tidak menunggu network untuk menampilkan data lokal.
- Error offline ditampilkan secara jelas, bukan crash.
- Sync retry aman dan idempotent.
- Data sensitif tidak ditulis ke log.
- Supabase secrets tidak berada di source Flutter.
- Accessibility: text readable, touch targets nyaman, kontras memadai.
- Currency formatting IDR konsisten.
- Tanggal/timezone menggunakan timezone lokal perangkat dengan penyimpanan timestamp yang konsisten.
