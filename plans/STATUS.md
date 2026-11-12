# Project Status

## Current phase
Planning / not implemented.

## Sprint status
- [ ] Sprint 00 — Foundation
- [ ] Sprint 01 — Cloud schema & security
- [ ] Sprint 02 — Local database & repository
- [ ] Sprint 03 — Groups & customers
- [ ] Sprint 04 — Debt management
- [ ] Sprint 05 — Payments & dashboard
- [ ] Sprint 06 — Admin PIN & sessions
- [ ] Sprint 07 — Offline sync
- [ ] Sprint 08 — Reminders
- [ ] Sprint 09 — QA, hardening & release

## Decisions
- One admin.
- Shared cloud data.
- No ordinary user login.
- Simple groups only (no subgroup).
- Offline-first with Drift/SQLite and outbox.
- Public reads must be explicitly approved and field-limited.
- Admin mutations must be server-authorized.

## Blockers / owner decisions
- [ ] Confirm which debt/customer fields are visible to anonymous users.
- [ ] Confirm whether public debt data is truly accessible to anyone or app should have a device/app access gate.
- [ ] Confirm PIN length and recovery/rotation process.
- [ ] Confirm exact reminder schedule and whether exact alarms are required.
- [ ] Confirm overpayment policy (default reject).
- [ ] Confirm delete/archive policy for debts, groups, customers.
