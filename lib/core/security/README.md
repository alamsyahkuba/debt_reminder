# Core security

Folder ini akan menampung utilitas sesi admin, penyimpanan token aman, dan
batas otorisasi sisi klien.

Aturan tetap:

- Jangan menyimpan PIN plaintext atau `service_role` key di aplikasi.
- PIN yang dibuka secara lokal hanya membuka akses edit lokal, bukan otorisasi
  cloud.
- Token admin disimpan di secure storage dan dibersihkan saat lock/logout.
- Setiap mutasi cloud tetap diverifikasi oleh server.
