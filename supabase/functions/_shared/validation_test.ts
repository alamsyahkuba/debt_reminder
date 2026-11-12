import assert from "node:assert/strict";

import {
  ensureAllowedFields,
  MAX_SAFE_RUPIAH,
  optionalString,
  readJsonObject,
  requireBoolean,
  requireIsoDate,
  requireIsoTimestamp,
  requireObject,
  requirePositiveAmount,
  requireString,
  requireUuid,
  requireVersion,
  ValidationError,
} from "./validation.ts";

function validationError(code: string) {
  return (error: unknown): boolean => {
    assert.ok(error instanceof ValidationError);
    assert.equal(error.code, code);
    return true;
  };
}

Deno.test("requireObject rejects arrays and null", () => {
  assert.throws(() => requireObject([]), validationError("invalid_payload"));
  assert.throws(() => requireObject(null), validationError("invalid_payload"));
  assert.deepEqual(requireObject({ id: 1 }), { id: 1 });
});

Deno.test("ensureAllowedFields rejects unknown keys", () => {
  assert.doesNotThrow(() =>
    ensureAllowedFields({ amount: 1 }, ["amount", "notes"])
  );
  assert.throws(
    () => ensureAllowedFields({ amount: 1, pin: "123456" }, ["amount"]),
    (error: unknown) => {
      assert.ok(error instanceof ValidationError);
      assert.equal(error.code, "unknown_fields");
      assert.deepEqual(error.details, { fields: ["pin"] });
      return true;
    },
  );
});

Deno.test("requireUuid normalizes valid UUIDs", () => {
  assert.equal(
    requireUuid("11111111-1111-4111-8111-111111111111", "debt_id"),
    "11111111-1111-4111-8111-111111111111",
  );
  assert.throws(
    () => requireUuid("not-a-uuid", "debt_id"),
    validationError("invalid_uuid"),
  );
});

Deno.test("requirePositiveAmount enforces safe integer rupiah", () => {
  assert.equal(requirePositiveAmount(1, "amount"), 1);
  assert.equal(
    requirePositiveAmount(MAX_SAFE_RUPIAH, "amount"),
    MAX_SAFE_RUPIAH,
  );
  assert.throws(
    () => requirePositiveAmount(0, "amount"),
    validationError("invalid_amount"),
  );
  assert.throws(
    () => requirePositiveAmount(-100, "amount"),
    validationError("invalid_amount"),
  );
  assert.throws(
    () => requirePositiveAmount(1.5, "amount"),
    validationError("invalid_amount"),
  );
  assert.throws(
    () => requirePositiveAmount(MAX_SAFE_RUPIAH + 1, "amount"),
    validationError("invalid_amount"),
  );
});

Deno.test("requireVersion requires a positive integer", () => {
  assert.equal(requireVersion(1), 1);
  assert.throws(() => requireVersion(0), validationError("invalid_version"));
  assert.throws(() => requireVersion(1.2), validationError("invalid_version"));
});

Deno.test("requireString trims and enforces length", () => {
  assert.equal(requireString("  Budi  ", "name"), "Budi");
  assert.throws(
    () => requireString("   ", "name"),
    validationError("invalid_string"),
  );
  assert.throws(
    () => requireString("a".repeat(201), "name", { maxLength: 200 }),
    validationError("invalid_string"),
  );
});

Deno.test("optionalString normalizes empty values to null", () => {
  assert.equal(optionalString(undefined, "notes"), null);
  assert.equal(optionalString(null, "notes"), null);
  assert.equal(optionalString("   ", "notes"), null);
  assert.equal(optionalString(" catatan ", "notes"), "catatan");
  assert.throws(
    () => optionalString(42, "notes"),
    validationError("invalid_string"),
  );
});

Deno.test("requireIsoDate rejects impossible dates", () => {
  assert.equal(requireIsoDate("2026-11-12", "due_date"), "2026-11-12");
  assert.throws(
    () => requireIsoDate("2026-02-31", "due_date"),
    validationError("invalid_date"),
  );
  assert.throws(
    () => requireIsoDate("12-11-2026", "due_date"),
    validationError("invalid_date"),
  );
});

Deno.test("requireIsoTimestamp requires an explicit timezone", () => {
  assert.equal(
    requireIsoTimestamp("2026-11-12T12:00:00Z", "paid_at"),
    "2026-11-12T12:00:00Z",
  );
  assert.equal(
    requireIsoTimestamp("2026-11-12T19:00:00+07:00", "paid_at"),
    "2026-11-12T19:00:00+07:00",
  );
  assert.throws(
    () => requireIsoTimestamp("2026-11-12T12:00:00", "paid_at"),
    validationError("invalid_timestamp"),
  );
});

Deno.test("requireBoolean rejects non-boolean values", () => {
  assert.equal(requireBoolean(true, "is_archived"), true);
  assert.throws(
    () => requireBoolean("true", "is_archived"),
    validationError("invalid_boolean"),
  );
});

Deno.test("readJsonObject parses JSON objects and rejects invalid input", async () => {
  const valid = await readJsonObject(
    new Request("http://localhost", {
      method: "POST",
      body: JSON.stringify({ amount: 1000 }),
      headers: { "content-type": "application/json" },
    }),
  );
  assert.deepEqual(valid, { amount: 1000 });

  await assert.rejects(
    () =>
      readJsonObject(
        new Request("http://localhost", {
          method: "POST",
          body: "{not-json",
        }),
      ),
    validationError("invalid_json"),
  );

  await assert.rejects(
    () =>
      readJsonObject(
        new Request("http://localhost", {
          method: "POST",
          body: JSON.stringify({ ok: true }),
          headers: { "content-length": "999999" },
        }),
      ),
    validationError("payload_too_large"),
  );
});
