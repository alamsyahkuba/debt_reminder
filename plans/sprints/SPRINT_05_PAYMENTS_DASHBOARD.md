# Sprint 05 — Payments & Dashboard

## Goal
Implement payment history, payment entry, and summary dashboard for the revised
group/debt/payment model.

## Tasks
- [x] Payment entity and append-only repository API.
- [x] Payment entry form.
- [x] Payment history in debt detail.
- [x] Validate amount > 0.
- [x] Reject overpayment by default.
- [x] Add operation_id idempotency key.
- [x] Dashboard totals and status counts.
- [x] Group summary totals.
- [x] Remove customer summary totals.
- [x] Currency formatting in Indonesian Rupiah.
- [x] Public read of payment data through RPC (existing Sprint 01R boundary,
      reverified by pgTAP).
- [x] Tests for payment aggregation, duplicate operation, and public read.

## Acceptance criteria
- [x] Payment recorded offline and visible immediately.
- [x] Retry cannot duplicate payment (unique `operation_id`, idempotent outbox
      entry).
- [x] Paid/outstanding totals are correct.
- [x] Payment history cannot be silently edited/deleted.
- [x] Dashboard aggregates match source records.
- [x] No customer summary or customer dependency exists.
- [x] Public users can read payment data but cannot mutate (backend RPC/RLS);
      public Flutter read-only mode/pull remains Sprint 07.

## Verification (13 November 2026)

| Check | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed .` | Passed |
| `flutter analyze` | Passed, no issues |
| `flutter test` | Passed; 40 tests |
| `flutter build apk --debug` | Passed |
| Payment form | Passed; amount, date, notes, confirmation |
| Overpayment rejection | Passed in repository and UI validation |
| Payment history | Passed; amount, date, notes |
| Dashboard totals/counts | Passed; totals, active/partial/overdue/paid |
| Group summary | Passed; active, archived-with-debts, and Unassigned |
| Upcoming due debts | Passed; overdue and next 7 days, paid excluded |
| `npx supabase@3.1.0 test db` | Passed; 92 pgTAP assertions |
| Deno function tests | Not rerun; Deno binary unavailable in this session |
| Android device launch | Not verified; no device connected |
