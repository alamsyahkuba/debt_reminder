import assert from "node:assert/strict";

import {
  DeviceAuthError,
  type DeviceAuthErrorCode,
  generateDeviceToken,
  getDeviceToken,
  hashDeviceToken,
  type ReadDeviceRecord,
  type ReadDeviceStore,
  requireReadDevice,
} from "./device_auth.ts";

const NOW = new Date("2026-11-12T12:00:00.000Z");
const FUTURE = "2027-05-11T12:00:00.000Z";
const PAST = "2026-11-11T12:00:00.000Z";

function device(overrides: Partial<ReadDeviceRecord> = {}): ReadDeviceRecord {
  return {
    id: "11111111-1111-4111-8111-111111111111",
    name: "HP keluarga",
    deviceId: "device-1",
    expiresAt: FUTURE,
    revokedAt: null,
    lastSeenAt: null,
    ...overrides,
  };
}

function requestWithToken(token: string): Request {
  return new Request("http://localhost/device-pull", {
    headers: { authorization: `Bearer ${token}` },
  });
}

function memoryStore(
  record: ReadDeviceRecord | null,
): { store: ReadDeviceStore; touched: string[] } {
  const touched: string[] = [];
  const store: ReadDeviceStore = {
    findByTokenHash: () => Promise.resolve(record),
    touch: (tokenHash) => {
      touched.push(tokenHash);
      return Promise.resolve();
    },
  };

  return { store, touched };
}

function deviceError(code: DeviceAuthErrorCode) {
  return (error: unknown): boolean => {
    assert.ok(error instanceof DeviceAuthError);
    assert.equal(error.code, code);
    return true;
  };
}

Deno.test("generateDeviceToken returns a prefixed opaque token", () => {
  const token = generateDeviceToken();

  assert.match(token, /^dr_dev_[A-Za-z0-9_-]{43}$/);
  assert.notEqual(token, generateDeviceToken());
});

Deno.test("hashDeviceToken is deterministic sha256 hex", async () => {
  const token = generateDeviceToken();
  const first = await hashDeviceToken(token);

  assert.match(first, /^[0-9a-f]{64}$/);
  assert.equal(first, await hashDeviceToken(token));
});

Deno.test("getDeviceToken rejects missing and malformed tokens", () => {
  assert.throws(
    () => getDeviceToken(new Request("http://localhost")),
    deviceError("missing_device_token"),
  );
  assert.throws(
    () =>
      getDeviceToken(
        new Request("http://localhost", {
          headers: { authorization: "Basic abc" },
        }),
      ),
    deviceError("invalid_device_token"),
  );
  assert.throws(
    () =>
      getDeviceToken(
        new Request("http://localhost", {
          headers: { authorization: "Bearer dr_dev_short" },
        }),
      ),
    deviceError("invalid_device_token"),
  );
});

Deno.test("requireReadDevice accepts an active device and touches it", async () => {
  const token = generateDeviceToken();
  const { store, touched } = memoryStore(device());
  const result = await requireReadDevice(requestWithToken(token), {
    store,
    now: NOW,
  });

  assert.equal(result.device.deviceId, "device-1");
  assert.equal(result.tokenHash, await hashDeviceToken(token));
  assert.deepEqual(touched, [result.tokenHash]);
});

Deno.test("requireReadDevice rejects an unknown token", async () => {
  const token = generateDeviceToken();
  const { store } = memoryStore(null);

  await assert.rejects(
    () => requireReadDevice(requestWithToken(token), { store, now: NOW }),
    deviceError("invalid_device_token"),
  );
});

Deno.test("requireReadDevice rejects a revoked device", async () => {
  const token = generateDeviceToken();
  const { store } = memoryStore(device({ revokedAt: PAST }));

  await assert.rejects(
    () => requireReadDevice(requestWithToken(token), { store, now: NOW }),
    deviceError("device_revoked"),
  );
});

Deno.test("requireReadDevice rejects an expired device", async () => {
  const token = generateDeviceToken();
  const { store } = memoryStore(device({ expiresAt: PAST }));

  await assert.rejects(
    () => requireReadDevice(requestWithToken(token), { store, now: NOW }),
    deviceError("device_expired"),
  );
});
