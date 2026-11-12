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
- [ ] Tests for invalid/expired session and rate limit.

## Acceptance criteria
- Client boolean cannot grant admin.
- Server rejects missing/invalid/expired token.
- PIN hash never returned to client.
- PIN attempts are rate-limited.
- Admin session can be locked.
- Offline edits remain queued; reconnect requires valid server session.
