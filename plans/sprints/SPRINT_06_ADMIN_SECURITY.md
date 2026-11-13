# Sprint 06 — Admin PIN & Session

## Goal
Implement admin unlock UI and server-authorized admin session. Public read does
not require login or device enrollment.

## Tasks
- [x] Implement PIN screen from drawer.
- [x] Implement PIN verification Edge Function.
- [x] Add rate limiting/attempt throttling.
- [x] Store short-lived admin token securely on device.
- [x] Add session expiry and lock/logout.
- [x] Implement PIN change endpoint and UI.
- [x] Add admin route guards.
- [x] Protect every existing mutation endpoint with server verification
      (`admin-pin` change/logout). Sprint 07 sync endpoints must use the same
      `requireAdminSession` helper.
- [x] Add audit log for admin operations.
- [x] Ensure offline unlock is explicitly local-only: offline unlock is not
      available; PIN verification requires the server.
- [x] Remove read-only device enrollment/token tasks and UI.
- [x] Tests for invalid/expired session and rate limit.
- [x] Tests that public read works without admin session.
- [x] Tests that public users cannot reach existing mutation endpoints.

## Acceptance criteria
- [x] Client boolean cannot grant admin.
- [x] Server rejects missing/invalid/expired token.
- [x] PIN hash never returned to client.
- [x] PIN attempts are rate-limited (5 attempts, 15-minute lockout).
- [x] Admin session can be locked.
- [x] Offline edits remain queued; reconnect mutation requires a valid server
      session. Sync mutation endpoints are Sprint 07.
- [x] Public read works without login or device enrollment.
- [x] No read-only device enrollment UI or `read_devices` dependency exists.

## Verification (13 November 2026)

| Check | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed .` | Passed |
| `flutter analyze` | Passed, no issues |
| `flutter test` | Passed; 48 tests |
| `flutter build apk --debug` | Passed |
| `deno fmt --check supabase/functions` | Passed |
| `deno check --config supabase/functions/deno.json ...` | Passed |
| `deno lint --config supabase/functions/deno.json ...` | Passed |
| `deno test --allow-env --allow-net supabase/functions` | Passed; 54 tests |
| `npx supabase@3.1.0 test db` | Passed; 125 pgTAP assertions |
| `npx supabase@3.1.0 db lint` | Passed |
| PIN verify → change → verify new PIN | Passed end-to-end locally |
| Missing admin token on change/logout | Rejected 401 |
| Revoked token on logout | Rejected 401 |
| Rate limit | Attempts 1–4 rejected 401; attempt 5 rejected 429 |
| Audit log | Rows appended for verify/change/logout/failures |
| Android device launch | Not verified; no device connected |
| Cloud deployment | Not performed; project not linked |

## Notes
- PIN policy chosen by owner: 6 digits, 5 failed attempts, 15-minute lockout,
  15-minute session.
- Admin token uses `x-admin-session` because Supabase's gateway reserves
  `Authorization` for Supabase JWTs.
- Initial PIN setup uses `ADMIN_INITIAL_PIN`; the database row starts as
  `uninitialized`, so bootstrap attempts are rate-limited too.
