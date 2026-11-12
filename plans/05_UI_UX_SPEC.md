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

### Debt detail
- Principal amount.
- Paid total and outstanding amount.
- Due date and notes.
- Payment history.
- Admin: edit, record payment, move group, archive.
- Tidak ada informasi customer.

### Payment form
- Amount, paid_at, notes.
- Validate positive amount and no overpayment by default.
- Confirmation before saving.
- Show offline/pending-sync status.
- Admin only.

### Admin PIN
- Numeric keypad atau secure input.
- Rate-limit feedback.
- No PIN in logs.
- Error generic enough not to expose internals.
- Session expiry/lock option.

### Settings
- Reminder schedule.
- Admin PIN change.
- Sync now.
- Pending operations and last sync.
- App version dan privacy note.
- Tidak ada menu perangkat read-only.

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
