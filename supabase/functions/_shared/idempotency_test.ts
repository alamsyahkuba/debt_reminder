import assert from "node:assert/strict";

import {
  claimOperation,
  completeOperation,
  failOperation,
  IdempotencyError,
  isReplay,
  type OperationClaim,
  payloadHash,
  type RpcClient,
} from "./idempotency.ts";

const OPERATION_ID = "22222222-2222-4222-8222-222222222222";
const HASH = "a".repeat(64);

const claim: OperationClaim = {
  operationId: OPERATION_ID,
  operation: "debt.create",
  entityType: "debt",
  entityId: "33333333-3333-4333-8333-333333333333",
  payloadHash: HASH,
};

function row(
  overrides: Record<string, unknown> = {},
): Record<string, unknown> {
  return {
    operation_id: OPERATION_ID,
    status: "processing",
    response: null,
    error_code: null,
    payload_hash: HASH,
    ...overrides,
  };
}

function fakeRpc(
  result: { data: unknown; error: null | { message: string; code?: string } },
): {
  rpc: RpcClient;
  calls: Array<{ name: string; args: Record<string, unknown> }>;
} {
  const calls: Array<{ name: string; args: Record<string, unknown> }> = [];
  const rpc: RpcClient = (name, args) => {
    calls.push({ name, args });
    return Promise.resolve(result);
  };

  return { rpc, calls };
}

Deno.test("payloadHash is stable regardless of key order", async () => {
  const first = await payloadHash({
    title: "Hutang",
    amount: 1000,
    nested: { b: 2, a: 1 },
  });
  const second = await payloadHash({
    nested: { a: 1, b: 2 },
    amount: 1000,
    title: "Hutang",
  });

  assert.match(first, /^[0-9a-f]{64}$/);
  assert.equal(first, second);
});

Deno.test("payloadHash rejects non-JSON values", async () => {
  await assert.rejects(
    () => payloadHash({ createdAt: new Date() }),
    (error: unknown) => {
      assert.ok(error instanceof IdempotencyError);
      assert.equal(error.code, "invalid_payload");
      return true;
    },
  );
});

Deno.test("claimOperation sends a stable claim and parses the row", async () => {
  const { rpc, calls } = fakeRpc({ data: row(), error: null });
  const result = await claimOperation(rpc, claim);

  assert.equal(calls.length, 1);
  const firstCall = calls[0];
  assert.ok(firstCall);
  assert.equal(firstCall.name, "begin_operation");
  assert.deepEqual(firstCall.args, {
    p_operation_id: OPERATION_ID,
    p_operation: "debt.create",
    p_entity_type: "debt",
    p_entity_id: claim.entityId,
    p_payload_hash: HASH,
    p_actor_type: "admin",
  });
  assert.equal(result.status, "processing");
  assert.equal(result.operationId, OPERATION_ID);
});

Deno.test("claimOperation accepts a single-row array response", async () => {
  const { rpc } = fakeRpc({
    data: [row({ status: "succeeded", response: { id: "debt-1" } })],
    error: null,
  });
  const result = await claimOperation(rpc, claim);

  assert.equal(result.status, "succeeded");
  assert.deepEqual(result.response, { id: "debt-1" });
  assert.equal(isReplay(result), true);
});

Deno.test("claimOperation maps payload mismatch to a typed error", async () => {
  const { rpc } = fakeRpc({
    data: null,
    error: { message: "operation_payload_mismatch", code: "P0001" },
  });

  await assert.rejects(
    () => claimOperation(rpc, claim),
    (error: unknown) => {
      assert.ok(error instanceof IdempotencyError);
      assert.equal(error.code, "payload_mismatch");
      return true;
    },
  );
});

Deno.test("completeOperation sends the stored response", async () => {
  const { rpc, calls } = fakeRpc({
    data: row({ status: "succeeded", response: { id: "debt-1" } }),
    error: null,
  });
  const result = await completeOperation(rpc, {
    operationId: OPERATION_ID,
    response: { id: "debt-1" },
  });

  const firstCall = calls[0];
  assert.ok(firstCall);
  assert.equal(firstCall.name, "complete_operation");
  assert.deepEqual(firstCall.args, {
    p_operation_id: OPERATION_ID,
    p_response: { id: "debt-1" },
    p_status: "succeeded",
    p_error_code: null,
  });
  assert.equal(result.status, "succeeded");
});

Deno.test("failOperation records a failure", async () => {
  const { rpc, calls } = fakeRpc({
    data: row({ status: "failed", error_code: "validation" }),
    error: null,
  });
  const result = await failOperation(rpc, {
    operationId: OPERATION_ID,
    errorCode: "validation",
  });

  const firstCall = calls[0];
  assert.ok(firstCall);
  assert.equal(firstCall.name, "fail_operation");
  assert.equal(result.status, "failed");
  assert.equal(result.errorCode, "validation");
});

Deno.test("isReplay is false only for in-progress rows", () => {
  assert.equal(
    isReplay({
      operationId: OPERATION_ID,
      status: "processing",
      response: null,
      errorCode: null,
      payloadHash: HASH,
    }),
    false,
  );
  assert.equal(
    isReplay({
      operationId: OPERATION_ID,
      status: "failed",
      response: null,
      errorCode: "validation",
      payloadHash: HASH,
    }),
    true,
  );
});
