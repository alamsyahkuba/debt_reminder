# UI/UX Specification

## 1. Navigation

Drawer:
- Dashboard
- Semua Hutang
- Group Hutang
- Pelanggan
- Reminder (optional list)
- Pengaturan
- Admin (PIN gate)

Admin menu opens PIN screen. Admin unlock reveals management actions; lock/logout returns to public mode.

## 2. Screens

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
- Search field.
- Filters: group, payment status, overdue, due date.
- Sort: due date, latest, outstanding amount, customer.
- Debt row shows title/customer, due date, remaining amount, status.

### Debt detail
- Customer information.
- Principal amount.
- Paid total and outstanding amount.
- Due date and notes.
- Payment history.
- Admin: edit, record payment, move group, archive.

### Customer list/detail
- Search.
- Debt count and outstanding summary.
- Admin CRUD/archive.

### Payment form
- Amount, paid_at, notes.
- Validate positive amount and no overpayment by default.
- Confirmation before saving.
- Show offline/pending-sync status.

### Admin PIN
- Numeric keypad or secure input.
- Rate-limit feedback.
- No PIN in logs.
- Error generic enough not to expose internals.
- Session expiry/lock option.

### Settings
- Reminder schedule.
- Admin PIN change.
- Sync now.
- Pending operations and last sync.
- Perangkat read-only: daftar perangkat, status aktif/revoked/expired, enroll
  perangkat baru, dan cabut akses.
- App version.

### Read-only device enrollment
- Admin menghasilkan kode enrollment sekali pakai (short-lived) atau QR.
- Perangkat baru memasukkan kode tersebut, lalu menyimpan token read-only di
  secure storage.
- Konfirmasi sebelum mencabut perangkat.
- Perangkat read-only menampilkan data tanpa aksi admin; jika token revoked/
  expired, tampilkan status dan tetap izinkan baca cache lokal.
- Enrollment tidak boleh menampilkan PIN atau token di log.

## 3. Visual rules
- Material 3.
- Responsive to small Android screens.
- Currency format `Rp 1.000.000` (locale Indonesia).
- Clear status colors with text labels; color alone is not sufficient.
- Loading, empty, error, offline, and pending-sync states for each data screen.
- Confirm destructive/archive actions.
- No subgroup UI.
