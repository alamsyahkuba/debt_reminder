import assert from "node:assert/strict";

import {
  hashPin,
  PIN_HASH_ALGORITHM,
  PinValidationError,
  validateInitialPin,
  validatePin,
  verifyPin,
} from "./pin.ts";

const PEPPER = "test-pepper-with-at-least-32-characters";
const PIN = "123456";

Deno.test("validatePin accepts exactly six digits", () => {
  assert.equal(validatePin(PIN), PIN);
  assert.throws(() => validatePin("12345"), PinValidationError);
  assert.throws(() => validatePin("1234567"), PinValidationError);
  assert.throws(() => validatePin("12a456"), PinValidationError);
  assert.throws(() => validatePin(123456), PinValidationError);
});

Deno.test("validateInitialPin accepts empty or a valid PIN", () => {
  assert.equal(validateInitialPin(undefined), null);
  assert.equal(validateInitialPin(""), null);
  assert.equal(validateInitialPin(PIN), PIN);
  assert.throws(() => validateInitialPin("1234"), PinValidationError);
});

Deno.test("hashPin creates a salted pbkdf2 hash and verifyPin accepts it", async () => {
  const hash = await hashPin(PIN, PEPPER);

  assert.match(
    hash,
    new RegExp(
      `^${PIN_HASH_ALGORITHM}\\$\\d+\\$[A-Za-z0-9_-]+\\$[A-Za-z0-9_-]+$`,
    ),
  );
  assert.equal(await verifyPin(PIN, hash, PEPPER), true);
  assert.equal(await verifyPin("654321", hash, PEPPER), false);
});

Deno.test("hashPin uses a different salt on every call", async () => {
  const first = await hashPin(PIN, PEPPER);
  const second = await hashPin(PIN, PEPPER);

  assert.notEqual(first, second);
  assert.equal(await verifyPin(PIN, first, PEPPER), true);
  assert.equal(await verifyPin(PIN, second, PEPPER), true);
});

Deno.test("verifyPin rejects malformed hashes and short peppers", async () => {
  assert.equal(await verifyPin(PIN, "not-a-hash", PEPPER), false);
  assert.equal(await verifyPin(PIN, "pbkdf2_sha256$1$abc$def", PEPPER), false);
  await assert.rejects(() => hashPin(PIN, "short"));
});
