# Project Brief — Debt Reminder Android

## 1. Ringkasan

Aplikasi Android untuk mencatat, mengelompokkan, memantau, dan mengingatkan hutang/piutang. Aplikasi memakai Flutter, Supabase PostgreSQL sebagai cloud database, dan SQLite lokal untuk penggunaan offline.

## 2. Keputusan produk yang sudah disepakati

| Area | Keputusan |
|---|---|
| Platform | Android, dibangun dengan Flutter |
| Backend | Supabase |
| Database cloud | PostgreSQL |
| Database lokal | SQLite melalui Drift |
| Pengguna | Owner/pemilik aplikasi |
| Admin | Satu admin |
| Login user biasa | Tidak ada login |
| Akses admin | Drawer → Admin → input PIN |
| Data | Shared database |
| Mode | Offline-first |
| Group hutang | Sederhana: Group → daftar hutang, tanpa subgroup |
| Reminder | Local notification |
| CRUD | Admin saja |
| User biasa | Read-only sesuai data yang diizinkan |

## 3. Tujuan

- Data hutang mudah dicari dan tidak berantakan.
- Hutang dapat dikelompokkan berdasarkan group.
- Pembayaran/cicilan memiliki histori.
- Reminder jatuh tempo tetap bekerja tanpa internet setelah jadwal tersimpan.
- Admin dapat mengelola data ketika offline.
- Data tersinkron ke Supabase saat koneksi kembali.
- Akses database tidak bergantung pada perlindungan UI semata.

## 4. Prinsip

1. Local-first: UI selalu berinteraksi melalui repository yang sumber baca utamanya SQLite.
2. Server-authoritative: Supabase memvalidasi operasi admin dan menyimpan data cloud.
3. Secure by default: anon tidak boleh memiliki hak mutasi.
4. Idempotent sync: retry tidak boleh membuat transaksi duplikat.
5. Auditability: operasi penting dicatat.
6. Data integrity: nominal dan histori pembayaran harus konsisten.
7. Simplicity: jangan menambahkan subgroup atau fitur di luar scope tanpa persetujuan.

## 5. Non-goals versi pertama

- Multi-admin.
- Login pelanggan/peminjam.
- Group bertingkat/subgroup.
- Web dashboard.
- Multi-tenant organisasi.
- Integrasi payment gateway.
- Reminder push notification server-side.
- Akuntansi lengkap atau jurnal double-entry.
