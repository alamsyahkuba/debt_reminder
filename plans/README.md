# Debt Reminder — AI Agent Planning Workspace

Folder ini adalah planning source-of-truth untuk membangun aplikasi Android
pengelolaan hutang menggunakan Flutter dan Supabase.

## Cara menggunakan

1. Baca `00_PROJECT_BRIEF.md` dan `01_PRODUCT_REQUIREMENTS.md`.
2. Baca `02_ARCHITECTURE.md`, `03_DATABASE_AND_SECURITY.md`, dan
   `04_OFFLINE_SYNC.md`.
3. Ikuti sprint secara berurutan dari `sprints/SPRINT_00_FOUNDATION.md`.
4. Sebelum mengerjakan sprint, agent harus membaca file sprint, memeriksa
   dependency sprint sebelumnya, lalu menyampaikan ringkasan scope dan rencana
   implementasi.
5. Setelah sprint selesai, agent wajib memperbarui `STATUS.md`, checklist
   sprint, keputusan teknis, dan dokumentasi yang terdampak.

## Aturan penting

- Jangan mengubah keputusan produk/arsitektur tanpa meminta persetujuan owner.
- Jangan menyimpan Supabase `service_role` key di aplikasi Flutter.
- PIN admin bukan autentikasi cloud yang aman jika hanya diperiksa di client.
- Semua operasi admin harus diverifikasi server-side.
- Publik hanya boleh membaca; publik tidak memiliki hak mutasi data.
- Semua field bisnis (group, hutang, pembayaran) bersifat publik melalui RPC
  read-only yang disetujui.
- Data admin, audit, sesi, PIN, token, dan metadata internal tetap privat.
- Tidak ada modul pelanggan.
- Tidak ada read-only device enrollment.
- Aplikasi harus local-first: UI membaca dan menulis melalui repository lokal.
- Semua mutasi offline admin masuk outbox dan harus idempotent saat dikirim.
- Pembayaran adalah transaksi append-only; jangan mengedit histori pembayaran
  secara diam-diam.
- Hindari hard delete data finansial; gunakan archive/soft-delete sesuai aturan.
- Jangan menandai sprint selesai sebelum acceptance criteria dan test terpenuhi.

## File utama

- `00_PROJECT_BRIEF.md` — visi dan keputusan produk.
- `01_PRODUCT_REQUIREMENTS.md` — requirement dan scope.
- `02_ARCHITECTURE.md` — arsitektur dan struktur Flutter.
- `03_DATABASE_AND_SECURITY.md` — schema, public RPC, RLS, admin security.
- `04_OFFLINE_SYNC.md` — SQLite, outbox, public pull, conflict, sync.
- `05_UI_UX_SPEC.md` — screen dan navigation.
- `06_TESTING_AND_ACCEPTANCE.md` — strategi test dan DoD.
- `07_AGENT_WORKFLOW.md` — instruksi operasional AI Agent.
- `STATUS.md` — status progres dan keputusan.
- `DECISIONS.md` — keputusan teknis yang diadopsi selama implementasi.
- `sprints/` — sprint planning per file.
