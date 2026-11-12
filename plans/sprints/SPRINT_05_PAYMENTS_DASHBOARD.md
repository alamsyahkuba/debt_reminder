# Sprint 05 — Payments & Dashboard

## Goal
Implement payment history, payment entry, and summary dashboard for the revised
group/debt/payment model.

## Tasks
- [ ] Payment entity and append-only repository API.
- [ ] Payment entry form.
- [ ] Payment history in debt detail.
- [ ] Validate amount > 0.
- [ ] Reject overpayment by default.
- [ ] Add operation_id idempotency key.
- [ ] Dashboard totals and status counts.
- [ ] Group summary totals.
- [ ] Remove customer summary totals.
- [ ] Currency formatting in Indonesian Rupiah.
- [ ] Public read of payment data through RPC.
- [ ] Tests for payment aggregation, duplicate operation, and public read.

## Acceptance criteria
- Payment recorded offline and visible immediately.
- Retry cannot duplicate payment.
- Paid/outstanding totals are correct.
- Payment history cannot be silently edited/deleted.
- Dashboard aggregates match source records.
- No customer summary or customer dependency exists.
- Public users can read payment data but cannot mutate.
