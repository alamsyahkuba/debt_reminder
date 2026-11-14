import assert from "node:assert/strict";

import {
  type AdminSessionStore,
  hashToken,
  signAdminToken,
} from "../_shared/auth.ts";
import {
  AdminMutationError,
  type ApplyMutationArgs,
  handleAdminSyncRequest,
} from "./handler.ts";

const SECRET = "test-secret-with-at-least-32-characters";
const NOW = new Date("2026-11-13T10:00:00.000Z");
const SESSION_ID = "11111111-1111-4111-8111-111111111111";
const DEVICE_ID = "test-device";

class MemorySessionStore implements AdminSessionStore {
  active = true;
  touched: string[] = [];

  isActive(): Promise<boolean> {
    return Promise.resolve(this.active);
  }

  touch(tokenHash: string): Promise<void> {
    this.touched.push(tokenHash);
    return Promise.resolve();
  }
}

async function adminToken(): Promise<string> {
  const signed = await signAdminToken({
    secret: SECRET,
    sessionId: SESSION_ID,
    deviceId: DEVICE_ID,
    issuedAt: NOW,
  });
  return signed.token;
}

function groupPayload() {
  return {
    id: "20000000-0000-4000-8000-000000000001",
    name: "Keluarga",
    description: null,
    color: "#00695C",
    icon: "family",
    sort_order: 1,
    is_archived: false,
    created_at: "2026-11-13T10:00:00Z",
    updated_at: "2026-11-13T10:00:00Z",
    version: 1,
  };
}

function request(
  body: Record<string, unknown>,
  token?: string,
): Request {
  return new Request("http://localhost/functions/v1/admin-sync", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      ...(token === undefined ? {} : { "x-admin-session": token }),
    },
    body: JSON.stringify(body),
  });
}

function validBody(overrides: Record<string, unknown> = {}) {
  return {
    operation_id: "10000000-0000-4000-8000-000000000001",
    operation: "create",
    entity_type: "debt_group",
    entity_id: "20000000-0000-4000-8000-000000000001",
    payload: groupPayload(),
    ...overrides,
  };
}

async function handle(
  body: Record<string, unknown>,
  options: {
    token?: string;
    result?: Record<string, unknown>;
    error?: Error;
  } = {},
): Promise<{ response: Response; args: ApplyMutationArgs[] }> {
  const store = new MemorySessionStore();
  const token = options.token ?? (await adminToken());
  const args: ApplyMutationArgs[] = [];

  const response = await handleAdminSyncRequest(request(body, token), {
    sessionSecret: SECRET,
    sessionStore: store,
    now: () => NOW,
    applyMutation: (value) => {
      args.push(value);
      if (options.error !== undefined) {
        return Promise.reject(options.error);
      }
      return Promise.resolve(
        options.result ?? {
          status: "applied",
          entity_type: "debt_group",
          entity_id: "20000000-0000-4000-8000-000000000001",
          version: 1,
          server_updated_at: "2026-11-13T10:00:01Z",
        },
      );
    },
  });

  return { response, args };
}

Deno.test("valid mutation is applied with authenticated session metadata", async () => {
  const { response, args } = await handle(validBody());
  const body = await response.json() as Record<string, unknown>;

  assert.equal(response.status, 200);
  assert.equal(body.status, "applied");
  assert.equal(args.length, 1);
  assert.equal(args[0]?.operationId, "10000000-0000-4000-8000-000000000001");
  assert.equal(args[0]?.sessionId, SESSION_ID);
  assert.equal(args[0]?.deviceId, DEVICE_ID);
  assert.match(args[0]?.payloadHash ?? "", /^[0-9a-f]{64}$/);
  assert.equal("token" in body, false);
});

Deno.test("missing admin session is rejected before mutation", async () => {
  const store = new MemorySessionStore();
  const response = await handleAdminSyncRequest(
    request(validBody()),
    {
      sessionSecret: SECRET,
      sessionStore: store,
      now: () => NOW,
      applyMutation: () => Promise.resolve({ status: "applied" }),
    },
  );

  assert.equal(response.status, 401);
  assert.deepEqual(store.touched, []);
});

Deno.test("unknown request and payload fields are rejected", async () => {
  const { response } = await handle(validBody({ unexpected: true }));
  assert.equal(response.status, 400);

  const unknownPayload = await handle(
    validBody({
      payload: { ...groupPayload(), unexpected: true },
    }),
  );
  assert.equal(unknownPayload.response.status, 400);
});

Deno.test("invalid operation and entity type are rejected", async () => {
  const invalidOperation = await handle(validBody({ operation: "delete_all" }));
  assert.equal(invalidOperation.response.status, 400);

  const invalidEntity = await handle(validBody({ entity_type: "customer" }));
  assert.equal(invalidEntity.response.status, 400);

  const mismatch = await handle(
    validBody({ entity_id: "20000000-0000-4000-8000-000000000002" }),
  );
  assert.equal(mismatch.response.status, 400);
});

Deno.test("payment operation id must match the queue operation id", async () => {
  const body = validBody({
    operation_id: "10000000-0000-4000-8000-000000000010",
    operation: "payment_create",
    entity_type: "payment",
    entity_id: "50000000-0000-4000-8000-000000000001",
    payload: {
      id: "50000000-0000-4000-8000-000000000001",
      debt_id: "40000000-0000-4000-8000-000000000001",
      amount: 250000,
      paid_at: "2026-11-13T10:05:00Z",
      notes: null,
      operation_id: "10000000-0000-4000-8000-000000000099",
      created_at: "2026-11-13T10:05:00Z",
    },
  });

  const { response } = await handle(body);
  assert.equal(response.status, 400);
});

function debtPayload(id: string, overrides: Record<string, unknown> = {}) {
  return {
    id,
    group_id: "20000000-0000-4000-8000-000000000001",
    title: "Hutang bulk",
    principal_amount: 100000,
    due_date: "2027-01-10",
    notes: null,
    is_archived: false,
    created_at: "2026-11-14T10:00:00Z",
    updated_at: "2026-11-14T10:00:00Z",
    version: 1,
    ...overrides,
  };
}

function batchBody(debts: Record<string, unknown>[]) {
  const batchId = "60000000-0000-4000-8000-000000000001";
  return validBody({
    operation_id: "10000000-0000-4000-8000-000000000030",
    operation: "create",
    entity_type: "debt_batch",
    entity_id: batchId,
    payload: { id: batchId, debts },
  });
}

Deno.test("bulk debt batch is validated and forwarded once", async () => {
  const debts = [
    debtPayload("40000000-0000-4000-8000-000000000011"),
    debtPayload("40000000-0000-4000-8000-000000000012", {
      title: "Hutang bulk kedua",
      principal_amount: 250000,
    }),
  ];
  const { response, args } = await handle(batchBody(debts), {
    result: {
      status: "applied",
      entity_type: "debt_batch",
      entity_id: "60000000-0000-4000-8000-000000000001",
      count: 2,
      debts: [],
    },
  });

  assert.equal(response.status, 200);
  assert.equal(args.length, 1);
  assert.equal(args[0]?.entityType, "debt_batch");
  assert.equal(args[0]?.operation, "create");
  assert.equal(args[0]?.entityId, "60000000-0000-4000-8000-000000000001");
  assert.equal((args[0]?.payload.debts as unknown[]).length, 2);
});

Deno.test("bulk debt batch rejects duplicate ids and invalid rows", async () => {
  const duplicateId = "40000000-0000-4000-8000-000000000011";
  const duplicate = await handle(
    batchBody([debtPayload(duplicateId), debtPayload(duplicateId)]),
  );
  assert.equal(duplicate.response.status, 400);

  const invalidAmount = await handle(
    batchBody([
      debtPayload("40000000-0000-4000-8000-000000000013", {
        principal_amount: 0,
      }),
    ]),
  );
  assert.equal(invalidAmount.response.status, 400);

  const unknownField = await handle(
    batchBody([
      debtPayload("40000000-0000-4000-8000-000000000014", {
        unexpected: true,
      }),
    ]),
  );
  assert.equal(unknownField.response.status, 400);
});

Deno.test("bulk debt batch rejects more than 50 rows and non-create operations", async () => {
  const debts = Array.from(
    { length: 51 },
    (_, index) =>
      debtPayload(
        `40000000-0000-4000-8000-${(index + 100).toString().padStart(12, "0")}`,
      ),
  );
  const oversized = await handle(batchBody(debts));
  assert.equal(oversized.response.status, 400);

  const nonCreate = await handle({
    ...batchBody([debtPayload("40000000-0000-4000-8000-000000000015")]),
    operation: "update",
  });
  assert.equal(nonCreate.response.status, 400);
});

Deno.test("debt delete requires a version and is accepted by the handler", async () => {
  const entityId = "40000000-0000-4000-8000-000000000001";
  const deleteBody = validBody({
    operation_id: "10000000-0000-4000-8000-000000000020",
    operation: "delete",
    entity_type: "debt",
    entity_id: entityId,
    payload: { id: entityId, expected_version: 2 },
  });

  const accepted = await handle(deleteBody, {
    result: {
      status: "applied",
      entity_type: "debt",
      entity_id: entityId,
      deleted: true,
    },
  });
  assert.equal(accepted.response.status, 200);
  assert.equal(accepted.args.length, 1);
  assert.equal(accepted.args[0]?.operation, "delete");
  assert.equal(accepted.args[0]?.entityType, "debt");
  assert.equal(accepted.args[0]?.payload.expected_version, 2);

  const missingVersion = await handle(
    validBody({
      operation_id: "10000000-0000-4000-8000-000000000021",
      operation: "delete",
      entity_type: "debt",
      entity_id: entityId,
      payload: { id: entityId },
    }),
  );
  assert.equal(missingVersion.response.status, 400);
});

Deno.test("version conflict is returned as 409 with server details", async () => {
  const { response } = await handle(validBody(), {
    result: {
      status: "conflict",
      entity_type: "debt_group",
      entity_id: "20000000-0000-4000-8000-000000000001",
      server_version: 3,
      server_updated_at: "2026-11-13T10:10:00Z",
      server_row: { name: "Server" },
    },
  });
  const body = await response.json() as Record<string, unknown>;

  assert.equal(response.status, 409);
  assert.deepEqual(body.error instanceof Object, true);
  assert.equal(
    (body.error as Record<string, unknown>).code,
    "version_conflict",
  );
  assert.equal(
    ((body.error as Record<string, unknown>).details as Record<string, unknown>)
      .server_version,
    3,
  );
});

Deno.test("missing server entity is returned as 404", async () => {
  const { response } = await handle(validBody(), {
    result: {
      status: "not_found",
      entity_type: "debt_group",
      entity_id: "20000000-0000-4000-8000-000000000001",
    },
  });

  assert.equal(response.status, 404);
});

Deno.test("mutation RPC errors are mapped without exposing internals", async () => {
  const validation = await handle(validBody(), {
    error: new AdminMutationError(
      "validation_error",
      "Pembayaran melebihi sisa hutang.",
      400,
    ),
  });
  assert.equal(validation.response.status, 400);

  const server = await handle(validBody(), {
    error: new AdminMutationError(
      "server_error",
      "Operasi sinkronisasi gagal di server.",
      500,
    ),
  });
  const body = await server.response.json() as Record<string, unknown>;
  assert.equal(server.response.status, 500);
  assert.equal(
    (body.error as Record<string, unknown>).code,
    "server_error",
  );
});

Deno.test("non-POST requests are rejected", async () => {
  const response = await handleAdminSyncRequest(
    new Request("http://localhost/functions/v1/admin-sync"),
    {
      sessionSecret: SECRET,
      sessionStore: new MemorySessionStore(),
      now: () => NOW,
      applyMutation: () => Promise.resolve({ status: "applied" }),
    },
  );

  assert.equal(response.status, 405);
});

Deno.test("session token hash is stable for replay-safe audit", async () => {
  const token = await adminToken();
  const first = await hashToken(token);
  const second = await hashToken(token);

  assert.equal(first, second);
  assert.match(first, /^[0-9a-f]{64}$/);
});
