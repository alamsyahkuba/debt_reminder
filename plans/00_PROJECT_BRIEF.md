# Project Brief — Debt Reminder Android

## 1. Ringkasan

Aplikasi Android untuk mencatat, mengelompokkan, memantau, dan mengingatkan
hutang/piutang. Aplikasi memakai Flutter, Supabase PostgreSQL sebagai cloud
database, dan SQLite lokal untuk penggunaan offline.

Data bisnis terdiri dari **group hutang, hutang, dan pembayaran**. Tidak ada
modul atau entitas pelanggan.

## 2. Keputusan produk yang sudah disepakati

| Area | Keputusan |
|---|---|
| Platform | Android, dibangun dengan Flutter |
| Backend | Supabase |
| Database cloud | PostgreSQL |
| Database lokal | SQLite melalui Drift |
| Pengguna | Owner/admin dan publik |
| Admin | Satu admin |
| Login publik | Tidak ada login |
| Akses admin | Drawer → Admin → input PIN |
| Data | Shared cloud database; group, hutang, dan pembayaran; tanpa data pelanggan |
| Mode | Offline-first |
| Group hutang | Sederhana: Group → daftar hutang, tanpa subgroup |
| Reminder | Local notification, dikonfigurasi admin |
| CRUD | Admin saja |
| Publik | Read-only untuk seluruh data bisnis |
| Public read | Semua field bisnis publik; data admin/audit/sesi tetap privat |
| Device enrollment | Tidak dipakai |

## 3. Tujuan

- Data hutang mudah dicari dan tidak berantakan.
- Hutang dapat dikelompokkan berdasarkan group.
- Pembayaran/cicilan memiliki histori.
- Reminder jatuh tempo tetap bekerja tanpa internet setelah jadwal tersimpan.
- Admin dapat mengelola data ketika offline.
- Data tersinkron ke Supabase saat koneksi kembali.
- Publik dapat melihat data terbaru tanpa login dan tanpa enrollment perangkat.
- Akses database tidak bergantung pada perlindungan UI semata.

## 4. Prinsip

1. Local-first: UI selalu berinteraksi melalui repository yang sumber baca
   utamanya SQLite.
2. Server-authoritative: Supabase memvalidasi operasi admin dan menyimpan data
   cloud.
3. Public read-only: publik boleh membaca data bisnis, tetapi tidak boleh
   melakukan mutasi.
4. Admin-only mutation: semua operasi tulis memerlukan sesi admin server-side.
5. Idempotent sync: retry tidak boleh membuat transaksi duplikat.
6. Auditability: operasi penting dicatat.
7. Data integrity: nominal dan histori pembayaran harus konsisten.
8. Simplicity: jangan menambahkan subgroup, pelanggan, atau fitur di luar scope
   tanpa persetujuan owner.

## 5. Non-goals versi pertama

- Multi-admin.
- Modul pelanggan/peminjam.
- Login publik atau login pelanggan.
- Read-only device enrollment.
- Group bertingkat/subgroup.
- Web dashboard.
- Multi-tenant organisasi.
- Integrasi payment gateway.
- Reminder push notification server-side.
- Akuntansi lengkap atau jurnal double-entry.

## 6. Catatan privasi

Semua field bisnis (group, hutang, dan pembayaran) bersifat publik. Siapa pun
yang memiliki anon/publishable key dapat membacanya melalui RPC publik. Ini
adalah keputusan owner.

Yang tetap privat: PIN hash, admin settings, admin sessions, audit logs,
operation registry, token, dan metadata sinkronisasi internal.
