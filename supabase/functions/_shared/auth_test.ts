import assert from "node:assert/strict";

import {
  ADMIN_SUBJECT,
  ADMIN_TOKEN_AUDIENCE,
  ADMIN_TOKEN_ISSUER,
  ADMIN_TOKEN_TTL_SECONDS,
  AdminAuthError,
  type AdminAuthErrorCode,
  type AdminSessionStore,
  getAdminToken,
  getBearerToken,
  hashToken,
  requireAdminSession,
  signAdminToken,
  verifyAdminToken,
} from "./auth.ts";

const SECRET = "test-secret-with-at-least-32-characters";
const NOW = new Date("2026-11-12T12:00:00.000Z");
const NOW_SECONDS = Math.floor(NOW.getTime() / 1000);
const SESSION_ID = "11111111-1111-4111-8111-111111111111";

function claims(overrides: Record<string, unknown> = {}) {
  return {
    iss: ADMIN_TOKEN_ISSUER,
    aud: ADMIN_TOKEN_AUDIENCE,
    sub: "admin",
    role: "admin",
    session_id: SESSION_ID,
    device_id: "device-1",
    iat: NOW_SECONDS,
    exp: NOW_SECONDS + ADMIN_TOKEN_TTL_SECONDS,
    ...overrides,
  };
}

function base64UrlEncode(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }

  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

function encodeJson(value: unknown): string {
  return base64UrlEncode(new TextEncoder().encode(JSON.stringify(value)));
}

async function signToken(
  payload: Record<string, unknown> = claims(),
  secret = SECRET,
): Promise<string> {
  const encodedHeader = encodeJson({ alg: "HS256", typ: "JWT" });
  const encodedPayload = encodeJson(payload);
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(`${encodedHeader}.${encodedPayload}`),
  );

  return `${encodedHeader}.${encodedPayload}.${
    base64UrlEncode(
      new Uint8Array(signature),
    )
  }`;
}

function authError(code: AdminAuthErrorCode) {
  return (error: unknown): boolean => {
    assert.ok(error instanceof AdminAuthError);
    assert.equal(error.code, code);
    return true;
  };
}

function requestWithToken(token: string): Request {
  return new Request("http://localhost/admin", {
    headers: { "x-admin-session": token },
  });
}

function memoryStore(active = true): {
  store: AdminSessionStore;
  touched: string[];
  checkedDevices: string[];
} {
  const touched: string[] = [];
  const checkedDevices: string[] = [];
  const store: AdminSessionStore = {
    isActive: (_tokenHash, deviceId) => {
      checkedDevices.push(deviceId);
      return Promise.resolve(active);
    },
    touch: (tokenHash) => {
      touched.push(tokenHash);
      return Promise.resolve();
    },
  };

  return { store, touched, checkedDevices };
}

Deno.test("verifyAdminToken returns typed claims for a valid token", async () => {
  const token = await signToken();
  const result = await verifyAdminToken(token, SECRET, NOW);

  assert.deepEqual(result, {
    subject: "admin",
    role: "admin",
    sessionId: SESSION_ID,
    deviceId: "device-1",
    issuedAt: NOW_SECONDS,
    expiresAt: NOW_SECONDS + ADMIN_TOKEN_TTL_SECONDS,
  });
});

Deno.test("verifyAdminToken rejects an expired token", async () => {
  const token = await signToken(
    claims({ iat: NOW_SECONDS - 1000, exp: NOW_SECONDS - 1 }),
  );

  await assert.rejects(
    () => verifyAdminToken(token, SECRET, NOW),
    authError("expired_token"),
  );
});

Deno.test("verifyAdminToken rejects wrong audience", async () => {
  const token = await signToken(claims({ aud: "another-app" }));

  await assert.rejects(
    () => verifyAdminToken(token, SECRET, NOW),
    authError("invalid_token"),
  );
});

Deno.test("verifyAdminToken rejects a tampered signature", async () => {
  const token = await signToken();
  const tampered = `${token.slice(0, -3)}abc`;

  await assert.rejects(
    () => verifyAdminToken(tampered, SECRET, NOW),
    authError("invalid_token"),
  );
});

Deno.test("verifyAdminToken rejects tokens with excessive lifetime", async () => {
  const token = await signToken(
    claims({ exp: NOW_SECONDS + ADMIN_TOKEN_TTL_SECONDS + 120 }),
  );

  await assert.rejects(
    () => verifyAdminToken(token, SECRET, NOW),
    authError("invalid_token"),
  );
});

Deno.test("verifyAdminToken rejects a short signing secret", async () => {
  const token = await signToken();

  await assert.rejects(
    () => verifyAdminToken(token, "short", NOW),
    authError("invalid_token"),
  );
});

Deno.test("getBearerToken rejects missing and malformed headers", () => {
  assert.throws(
    () => getBearerToken(new Request("http://localhost")),
    authError("missing_token"),
  );
  assert.throws(
    () =>
      getBearerToken(
        new Request("http://localhost", {
          headers: { authorization: "Basic abc" },
        }),
      ),
    authError("invalid_token"),
  );
});

Deno.test("getAdminToken reads only the custom session header", () => {
  assert.equal(
    getAdminToken(requestWithToken("admin-token")),
    "admin-token",
  );
  assert.throws(
    () => getAdminToken(new Request("http://localhost")),
    authError("missing_token"),
  );
  assert.throws(
    () =>
      getAdminToken(
        new Request("http://localhost", {
          headers: { authorization: "Bearer admin-token" },
        }),
      ),
    authError("missing_token"),
  );
  assert.throws(
    () =>
      getAdminToken(
        new Request("http://localhost", {
          headers: { "x-admin-session": "bad token" },
        }),
      ),
    authError("invalid_token"),
  );
});

Deno.test("hashToken is deterministic sha256 hex", async () => {
  const token = await signToken();
  const first = await hashToken(token);
  const second = await hashToken(token);

  assert.match(first, /^[0-9a-f]{64}$/);
  assert.equal(first, second);
});

Deno.test("requireAdminSession checks the store and touches the session", async () => {
  const token = await signToken();
  const { store, touched, checkedDevices } = memoryStore(true);
  const result = await requireAdminSession(requestWithToken(token), {
    secret: SECRET,
    store,
    now: NOW,
  });

  assert.equal(result.claims.subject, "admin");
  assert.equal(result.tokenHash, await hashToken(token));
  assert.deepEqual(touched, [result.tokenHash]);
  assert.deepEqual(checkedDevices, ["device-1"]);
});

Deno.test("requireAdminSession rejects a revoked session", async () => {
  const token = await signToken();
  const { store, touched } = memoryStore(false);

  await assert.rejects(
    () =>
      requireAdminSession(requestWithToken(token), {
        secret: SECRET,
        store,
        now: NOW,
      }),
    authError("session_revoked"),
  );
  assert.deepEqual(touched, []);
});

Deno.test("signAdminToken creates a verifiable short-lived token", async () => {
  const signed = await signAdminToken({
    secret: SECRET,
    sessionId: SESSION_ID,
    deviceId: "device-1",
    issuedAt: NOW,
  });
  const claims = await verifyAdminToken(signed.token, SECRET, NOW);

  assert.deepEqual(claims, {
    subject: ADMIN_SUBJECT,
    role: "admin",
    sessionId: SESSION_ID,
    deviceId: "device-1",
    issuedAt: NOW_SECONDS,
    expiresAt: NOW_SECONDS + ADMIN_TOKEN_TTL_SECONDS,
  });
  assert.equal(
    signed.expiresAt.getTime(),
    (NOW_SECONDS + ADMIN_TOKEN_TTL_SECONDS) * 1000,
  );
});

Deno.test("signAdminToken rejects invalid options", async () => {
  await assert.rejects(() =>
    signAdminToken({
      secret: SECRET,
      sessionId: "not-a-uuid",
      deviceId: "device-1",
      issuedAt: NOW,
    })
  );
  await assert.rejects(() =>
    signAdminToken({
      secret: SECRET,
      sessionId: SESSION_ID,
      deviceId: "device-1",
      issuedAt: NOW,
      ttlSeconds: ADMIN_TOKEN_TTL_SECONDS + 1,
    })
  );
  await assert.rejects(() =>
    signAdminToken({
      secret: "short",
      sessionId: SESSION_ID,
      deviceId: "device-1",
      issuedAt: NOW,
    })
  );
});
