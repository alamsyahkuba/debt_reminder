import assert from "node:assert/strict";

import { randomToken, sha256Hex } from "./crypto.ts";

Deno.test("sha256Hex matches a known SHA-256 vector", async () => {
  assert.equal(
    await sha256Hex("abc"),
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  );
});

Deno.test("randomToken uses a prefix and 32 random bytes by default", () => {
  const first = randomToken("dr_dev_");
  const second = randomToken("dr_dev_");

  assert.match(first, /^dr_dev_[A-Za-z0-9_-]{43}$/);
  assert.notEqual(first, second);
});

Deno.test("randomToken rejects short byte lengths", () => {
  assert.throws(() => randomToken("x_", 8), RangeError);
});
