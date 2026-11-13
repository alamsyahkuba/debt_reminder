import assert from "node:assert/strict";

import {
  type AdminAuditEntry,
  type AdminPinAttempt,
  type AdminPinHash,
  type AdminPinStore,
  handleAdminPinRequest,
} from "./handler.ts";
import { hashToken } from "../_shared/auth.ts";
import { hashPin, PIN_HASH_ALGORITHM, verifyPin } from "../_shared/pin.ts";

const SECRET = "test-secret-with-at-least-32-characters";
const PEPPER = "test-pepper-with-at-least-32-characters";
const NOW = new Date("2026-11-13T10:00:00.000Z");
const PIN = "123456";
const NEW_PIN = "654321";

class MemoryAdminPinStore implements AdminPinStore {
  pinHash: string | null = null;
  failures = 0;
  lockedUntil: Date | null = null;
  readonly sessions = new Map<
    string,
    { deviceId: string; expiresAt: Date; revoked: boolean }
  >();
  readonly audits: AdminAuditEntry[] = [];
  readonly touched: string[] = [];

  beginPinAttempt(options: {
    now: Date;
    maxAttempts: number;
    lockSeconds: number;
  }): Promise<AdminPinAttempt> {
    if (this.lockedUntil !== null && this.lockedUntil > options.now) {
      return Promise.resolve({
        allowed: false,
        hasPin: this.pinHash !== null,
        retryAfterSeconds: Math.max(
          1,
          Math.ceil(
            (this.lockedUntil.getTime() - options.now.getTime()) / 1000,
          ),
        ),
        failedAttemptCount: this.failures,
      });
    }

    const next = (this.lockedUntil !== null ? 0 : this.failures) + 1;
    if (next >= options.maxAttempts) {
      this.failures = next;
      this.lockedUntil = new Date(
        options.now.getTime() + options.lockSeconds * 1000,
      );
      return Promise.resolve({
        allowed: false,
        hasPin: this.pinHash !== null,
        retryAfterSeconds: options.lockSeconds,
        failedAttemptCount: next,
      });
    }

    this.failures = next;
    this.lockedUntil = null;
    return Promise.resolve({
      allowed: true,
      hasPin: this.pinHash !== null,
      retryAfterSeconds: 0,
      failedAttemptCount: next,
    });
  }

  getPinHash(): Promise<AdminPinHash | null> {
    return Promise.resolve(
      this.pinHash === null
        ? null
        : { hash: this.pinHash, algorithm: PIN_HASH_ALGORITHM },
    );
  }

  setPinHash(hash: string): Promise<void> {
    this.pinHash = hash;
    return Promise.resolve();
  }

  resetPinAttempts(): Promise<void> {
    this.failures = 0;
    this.lockedUntil = null;
    return Promise.resolve();
  }

  createSession(options: {
    sessionId: string;
    tokenHash: string;
    deviceId: string;
    expiresAt: Date;
    now: Date;
  }): Promise<void> {
    assert.ok(options.sessionId.length > 0);
    assert.ok(options.expiresAt > options.now);
    this.sessions.set(options.tokenHash, {
      deviceId: options.deviceId,
      expiresAt: options.expiresAt,
      revoked: false,
    });
    return Promise.resolve();
  }

  isActive(tokenHash: string, deviceId: string, now: Date): Promise<boolean> {
    const session = this.sessions.get(tokenHash);
    return Promise.resolve(
      session !== undefined &&
        !session.revoked &&
        session.deviceId === deviceId &&
        session.expiresAt > now,
    );
  }

  touch(tokenHash: string): Promise<void> {
    this.touched.push(tokenHash);
    return Promise.resolve();
  }

  revokeSession(tokenHash: string, now: Date): Promise<boolean> {
    const session = this.sessions.get(tokenHash);
    if (
      session === undefined ||
      session.revoked ||
      session.expiresAt <= now
    ) {
      return Promise.resolve(false);
    }

    session.revoked = true;
    return Promise.resolve(true);
  }

  revokeOtherSessions(tokenHash: string, now: Date): Promise<number> {
    let revoked = 0;
    for (const [hash, session] of this.sessions) {
      if (
        hash !== tokenHash &&
        !session.revoked &&
        session.expiresAt > now
      ) {
        session.revoked = true;
        revoked++;
      }
    }

    return Promise.resolve(revoked);
  }

  appendAudit(entry: AdminAuditEntry): Promise<void> {
    this.audits.push(entry);
    return Promise.resolve();
  }
}

function deps(
  store: MemoryAdminPinStore,
  overrides: Partial<{
    initialPin: string | null;
    maxAttempts: number;
    lockSeconds: number;
  }> = {},
) {
  return {
    store,
    sessionSecret: SECRET,
    pinPepper: PEPPER,
    initialPin: overrides.initialPin === undefined ? PIN : overrides.initialPin,
    maxAttempts: overrides.maxAttempts ?? 5,
    lockSeconds: overrides.lockSeconds ?? 900,
    now: () => NOW,
  };
}

function request(
  body: Record<string, unknown>,
  token?: string,
): Request {
  return new Request("http://localhost/functions/v1/admin-pin", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      ...(token === undefined ? {} : { "x-admin-session": token }),
    },
    body: JSON.stringify(body),
  });
}

async function verifyRequest(
  store: MemoryAdminPinStore,
  pin = PIN,
  options: Partial<{
    initialPin: string | null;
    maxAttempts: number;
    lockSeconds: number;
  }> = {},
): Promise<Response> {
  return await handleAdminPinRequest(
    request({ action: "verify", pin, device_id: "device-1" }),
    deps(store, options),
  );
}

function jsonBody(response: Response): Promise<Record<string, unknown>> {
  return response.json() as Promise<Record<string, unknown>>;
}

Deno.test("verify bootstraps the initial PIN and returns only a session token", async () => {
  const store = new MemoryAdminPinStore();
  const response = await verifyRequest(store);

  assert.equal(response.status, 200);
  const body = await jsonBody(response);
  assert.equal(typeof body.token, "string");
  assert.equal(body.token_type, "Bearer");
  assert.equal(typeof body.expires_at, "string");
  assert.equal(body.pin_hash, undefined);
  assert.ok(store.pinHash !== null);
  assert.equal(await verifyPin(PIN, store.pinHash, PEPPER), true);
  assert.equal(store.audits.at(-1)?.action, "admin_pin_verified");
});

Deno.test("wrong PIN is rejected and audited", async () => {
  const store = new MemoryAdminPinStore();
  store.pinHash = await hashPin(PIN, PEPPER);

  const response = await verifyRequest(store, "000000");
  const body = await jsonBody(response);

  assert.equal(response.status, 401);
  assert.equal(body.error instanceof Object, true);
  assert.equal(store.failures, 1);
  assert.equal(store.audits.at(-1)?.action, "admin_pin_failed");
});

Deno.test("rate limit rejects the attempt after the configured threshold", async () => {
  const store = new MemoryAdminPinStore();
  store.pinHash = await hashPin(PIN, PEPPER);

  const first = await verifyRequest(store, "000000", { maxAttempts: 2 });
  assert.equal(first.status, 401);

  const second = await verifyRequest(store, "000000", {
    maxAttempts: 2,
    lockSeconds: 600,
  });
  assert.equal(second.status, 429);
  const body = await jsonBody(second);
  assert.deepEqual(body.error, {
    code: "rate_limited",
    message: "Terlalu banyak percobaan PIN. Coba lagi nanti.",
    details: { retry_after_seconds: 600 },
  });
});

Deno.test("PIN change requires a valid admin session", async () => {
  const store = new MemoryAdminPinStore();
  const response = await handleAdminPinRequest(
    request({
      action: "change",
      current_pin: PIN,
      new_pin: NEW_PIN,
    }),
    deps(store),
  );

  assert.equal(response.status, 401);
  assert.equal(store.pinHash, null);
});

Deno.test("PIN change updates the hash and revokes other sessions", async () => {
  const store = new MemoryAdminPinStore();
  const login = await verifyRequest(store);
  const token = (await jsonBody(login)).token;
  assert.equal(typeof token, "string");

  const otherHash = await hashToken("other-session-token");
  await store.createSession({
    sessionId: crypto.randomUUID(),
    tokenHash: otherHash,
    deviceId: "device-2",
    expiresAt: new Date(NOW.getTime() + 60_000),
    now: NOW,
  });

  const response = await handleAdminPinRequest(
    request(
      {
        action: "change",
        current_pin: PIN,
        new_pin: NEW_PIN,
      },
      token as string,
    ),
    deps(store),
  );

  assert.equal(response.status, 200);
  const body = await jsonBody(response);
  assert.equal(body.revoked_sessions, 1);
  assert.ok(store.pinHash !== null);
  assert.equal(await verifyPin(NEW_PIN, store.pinHash, PEPPER), true);
  assert.equal(await verifyPin(PIN, store.pinHash, PEPPER), false);
  assert.equal(await store.isActive(otherHash, "device-2", NOW), false);
  assert.equal(store.audits.at(-1)?.action, "admin_pin_changed");
});

Deno.test("logout revokes the current session", async () => {
  const store = new MemoryAdminPinStore();
  const login = await verifyRequest(store);
  const token = (await jsonBody(login)).token as string;
  const tokenHash = await hashToken(token);

  const response = await handleAdminPinRequest(
    request({ action: "logout" }, token),
    deps(store),
  );

  assert.equal(response.status, 200);
  assert.equal(await store.isActive(tokenHash, "device-1", NOW), false);
  assert.equal(store.audits.at(-1)?.action, "admin_logout");
});

Deno.test("verify reports missing configuration without revealing a hash", async () => {
  const store = new MemoryAdminPinStore();
  const response = await verifyRequest(store, PIN, { initialPin: null });

  assert.equal(response.status, 503);
  const body = await jsonBody(response);
  assert.equal(body.error instanceof Object, true);
  assert.equal(store.pinHash, null);
});

Deno.test("wrong bootstrap PIN does not persist a hash", async () => {
  const store = new MemoryAdminPinStore();
  const response = await verifyRequest(store, "000000");

  assert.equal(response.status, 401);
  assert.equal(store.pinHash, null);
  assert.equal(store.audits.at(-1)?.action, "admin_pin_bootstrap_failed");
});

Deno.test("bootstrap attempts are rate-limited too", async () => {
  const store = new MemoryAdminPinStore();

  const first = await verifyRequest(store, "000000", { maxAttempts: 2 });
  assert.equal(first.status, 401);

  const second = await verifyRequest(store, "000000", { maxAttempts: 2 });
  assert.equal(second.status, 429);
  assert.equal(store.pinHash, null);
});

Deno.test("invalid PIN format and unsupported methods are rejected", async () => {
  const store = new MemoryAdminPinStore();
  const invalidPin = await verifyRequest(store, "12345");
  assert.equal(invalidPin.status, 400);

  const getResponse = await handleAdminPinRequest(
    new Request("http://localhost/functions/v1/admin-pin"),
    deps(store),
  );
  assert.equal(getResponse.status, 405);
});
