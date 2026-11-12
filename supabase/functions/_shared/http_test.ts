import assert from "node:assert/strict";

import { AdminAuthError } from "./auth.ts";
import { IdempotencyError } from "./idempotency.ts";
import { ValidationError } from "./validation.ts";
import { errorResponse, handleError, jsonResponse } from "./http.ts";

Deno.test("jsonResponse serializes JSON and status", async () => {
  const response = jsonResponse({ ok: true }, 201);

  assert.equal(response.status, 201);
  assert.match(response.headers.get("content-type") ?? "", /application\/json/);
  assert.deepEqual(await response.json(), { ok: true });
});

Deno.test("errorResponse omits details when absent", async () => {
  const response = errorResponse("validation", "Tidak valid", 400);

  assert.equal(response.status, 400);
  assert.deepEqual(await response.json(), {
    error: { code: "validation", message: "Tidak valid" },
  });
});

Deno.test("handleError maps auth, validation, and idempotency errors", async () => {
  const authResponse = handleError(new AdminAuthError("expired_token"));
  assert.equal(authResponse.status, 401);

  const validationResponse = handleError(
    new ValidationError("invalid_amount", "Nominal tidak valid", {
      field: "amount",
    }),
  );
  assert.equal(validationResponse.status, 400);
  assert.deepEqual(await validationResponse.json(), {
    error: {
      code: "invalid_amount",
      message: "Nominal tidak valid",
      details: { field: "amount" },
    },
  });

  const conflictResponse = handleError(
    new IdempotencyError("payload_mismatch", "Operation ID sudah dipakai."),
  );
  assert.equal(conflictResponse.status, 409);
});

Deno.test("handleError hides internal errors", async () => {
  const response = handleError(new Error("database password leaked"));
  const body = await response.json();

  assert.equal(response.status, 500);
  assert.deepEqual(body, {
    error: {
      code: "internal_error",
      message: "Terjadi kesalahan pada server.",
    },
  });
});
