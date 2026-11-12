/**
 * Idempotency helpers for admin Edge Functions.
 *
 * The database is the source of truth: begin_operation() atomically claims an
 * operation_id and returns the prior result on retries. Edge Functions must:
 *   1. claim the operation with a stable operation_id;
 *   2. return the stored response when the claim is a replay;
 *   3. complete/fail the operation in the same server request.
 */

export type OperationStatus = "processing" | "succeeded" | "failed";
export type OperationActorType = "admin" | "system";

export interface OperationRow {
  operationId: string;
  status: OperationStatus;
  response: unknown;
  errorCode: string | null;
  payloadHash: string;
}

export interface OperationClaim {
  operationId: string;
  operation: string;
  entityType: string;
  entityId: string | null;
  payloadHash: string;
  actorType?: OperationActorType;
}

export interface RpcError {
  message: string;
  code?: string;
  details?: string;
  hint?: string;
}

export interface RpcResponse {
  data: unknown;
  error: RpcError | null;
}

export type RpcClient = (
  functionName: string,
  args: Record<string, unknown>,
) => PromiseLike<RpcResponse>;

export type IdempotencyErrorCode =
  | "invalid_payload"
  | "invalid_response"
  | "payload_mismatch"
  | "operation_not_found"
  | "operation_already_completed"
  | "rpc_failed";

export class IdempotencyError extends Error {
  constructor(
    readonly code: IdempotencyErrorCode,
    message: string,
    readonly causeCode?: string,
  ) {
    super(message);
    this.name = "IdempotencyError";
  }
}

export async function claimOperation(
  rpc: RpcClient,
  claim: OperationClaim,
): Promise<OperationRow> {
  const response = await rpc("begin_operation", {
    p_operation_id: claim.operationId,
    p_operation: claim.operation,
    p_entity_type: claim.entityType,
    p_entity_id: claim.entityId,
    p_payload_hash: claim.payloadHash,
    p_actor_type: claim.actorType ?? "admin",
  });

  if (response.error) {
    throw mapRpcError(response.error);
  }

  return parseOperationRow(response.data);
}

export async function completeOperation(
  rpc: RpcClient,
  input: {
    operationId: string;
    response: unknown;
    status?: "succeeded" | "failed";
    errorCode?: string | null;
  },
): Promise<OperationRow> {
  const status = input.status ?? "succeeded";

  if (status === "succeeded" && input.response === undefined) {
    throw new IdempotencyError(
      "invalid_payload",
      "Response wajib diisi untuk operasi yang berhasil.",
    );
  }

  const response = await rpc("complete_operation", {
    p_operation_id: input.operationId,
    p_response: input.response ?? null,
    p_status: status,
    p_error_code: input.errorCode ?? null,
  });

  if (response.error) {
    throw mapRpcError(response.error);
  }

  return parseOperationRow(response.data);
}

export async function failOperation(
  rpc: RpcClient,
  input: { operationId: string; errorCode: string },
): Promise<OperationRow> {
  const response = await rpc("fail_operation", {
    p_operation_id: input.operationId,
    p_error_code: input.errorCode,
  });

  if (response.error) {
    throw mapRpcError(response.error);
  }

  return parseOperationRow(response.data);
}

export function isReplay(row: OperationRow): boolean {
  return row.status === "succeeded" || row.status === "failed";
}

export async function payloadHash(payload: unknown): Promise<string> {
  const canonical = JSON.stringify(canonicalize(payload));
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(canonical),
  );

  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function canonicalize(value: unknown): unknown {
  if (
    value === null ||
    typeof value === "string" ||
    typeof value === "boolean"
  ) {
    return value;
  }

  if (typeof value === "number") {
    if (!Number.isFinite(value)) {
      throw new IdempotencyError(
        "invalid_payload",
        "Payload memuat angka yang tidak valid.",
      );
    }
    return value;
  }

  if (Array.isArray(value)) {
    return value.map(canonicalize);
  }

  if (typeof value === "object") {
    const prototype = Object.getPrototypeOf(value);
    if (prototype !== Object.prototype && prototype !== null) {
      throw new IdempotencyError(
        "invalid_payload",
        "Payload harus berupa JSON biasa.",
      );
    }

    const record = value as Record<string, unknown>;
    const result: Record<string, unknown> = {};

    for (const key of Object.keys(record).sort()) {
      if (record[key] !== undefined) {
        result[key] = canonicalize(record[key]);
      }
    }

    return result;
  }

  throw new IdempotencyError(
    "invalid_payload",
    "Payload memuat tipe data yang tidak didukung.",
  );
}

function parseOperationRow(raw: unknown): OperationRow {
  const value = Array.isArray(raw) ? raw[0] : raw;

  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new IdempotencyError(
      "invalid_response",
      "Respons idempotensi dari server tidak valid.",
    );
  }

  const row = value as Record<string, unknown>;
  const status = row.status;
  const operationId = row.operation_id;
  const payloadHash = row.payload_hash;

  if (
    typeof operationId !== "string" ||
    typeof payloadHash !== "string" ||
    (status !== "processing" &&
      status !== "succeeded" &&
      status !== "failed")
  ) {
    throw new IdempotencyError(
      "invalid_response",
      "Respons idempotensi dari server tidak valid.",
    );
  }

  return {
    operationId,
    status,
    response: row.response ?? null,
    errorCode: typeof row.error_code === "string" ? row.error_code : null,
    payloadHash,
  };
}

function mapRpcError(error: RpcError): IdempotencyError {
  const message = error.message ?? "";

  if (message.includes("operation_payload_mismatch")) {
    return new IdempotencyError(
      "payload_mismatch",
      "Operation ID sudah dipakai untuk payload yang berbeda.",
      error.code,
    );
  }

  if (message.includes("operation_metadata_mismatch")) {
    return new IdempotencyError(
      "payload_mismatch",
      "Operation ID sudah dipakai untuk operasi yang berbeda.",
      error.code,
    );
  }

  if (message.includes("operation_not_found")) {
    return new IdempotencyError(
      "operation_not_found",
      "Operasi tidak ditemukan.",
      error.code,
    );
  }

  if (message.includes("operation_already_completed")) {
    return new IdempotencyError(
      "operation_already_completed",
      "Operasi sudah selesai dengan hasil berbeda.",
      error.code,
    );
  }

  return new IdempotencyError(
    "rpc_failed",
    "Operasi idempotensi gagal diproses.",
    error.code,
  );
}
