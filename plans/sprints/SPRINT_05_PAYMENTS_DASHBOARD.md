# Sprint 05 — Payments & Dashboard

## Goal
Implement payment history, payment entry, and summary dashboard.

## Tasks
- [ ] Payment entity and append-only repository API.
- [ ] Payment entry form.
- [ ] Payment history in debt detail.
- [ ] Validate amount > 0.
- [ ] Reject overpayment by default.
- [ ] Add operation_id idempotency key.
- [ ] Dashboard totals and status counts.
- [ ] Group summary totals.
- [ ] Customer summary totals.
- [ ] Currency formatting in Indonesian Rupiah.
- [ ] Tests for payment aggregation and duplicate operation.

## Acceptance criteria
- Payment recorded offline and visible immediately.
- Retry cannot duplicate payment.
- Paid/outstanding totals are correct.
- Payment history cannot be silently edited/deleted.
- Dashboard aggregates match source records.
