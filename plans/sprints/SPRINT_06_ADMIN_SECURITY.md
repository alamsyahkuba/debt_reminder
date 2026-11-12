# Sprint 06 — Admin PIN & Session

## Goal
Implement admin unlock UI and server-authorized admin session.

## Tasks
- [ ] Implement PIN screen from drawer.
- [ ] Implement PIN verification Edge Function.
- [ ] Add rate limiting/attempt throttling.
- [ ] Store short-lived admin token securely on device.
- [ ] Add session expiry and lock/logout.
- [ ] Implement PIN change endpoint and UI.
- [ ] Add admin route guards.
- [ ] Protect every mutation endpoint with server verification.
- [ ] Add audit log for admin operations.
- [ ] Ensure offline unlock is explicitly local-only.
- [ ] Implement read-only device enrollment/revocation endpoint and UI.
- [ ] Generate one-time enrollment code; return device token only once and store
      only its SHA-256 hash in `read_devices`.
- [ ] Add device list/status/revoke UI under Settings or Admin.
- [ ] Record device enrollment/revocation in audit logs.
- [ ] Tests for invalid/expired session, rate limit, one-time enrollment, and
      revoked device.

## Acceptance criteria
- Client boolean cannot grant admin.
- Server rejects missing/invalid/expired token.
- PIN hash never returned to client.
- PIN attempts are rate-limited.
- Admin session can be locked.
- Offline edits remain queued; reconnect requires valid server session.
- Admin can enroll a read-only device; token is returned once and only its hash
  is stored.
- Admin can revoke a read-only device and revocation takes effect on the next
  pull.
- Device enrollment/revocation is audited without logging secrets.
