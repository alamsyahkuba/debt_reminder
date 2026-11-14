/**
 * Admin outbox mutation handler.
 *
 * Request body:
 *   {operation_id, operation, entity_type, entity_id, payload}
 * Header:
 *   x-admin-session: <admin JWT>
 *
 * The handler validates the payload, verifies the server session, and calls
 * the atomic PostgreSQL mutation RPC. It is intentionally separate from the
 * Deno entry point for unit testing.
 */

import {
  type AdminSessionStore,
  requireAdminSession,
} from "../_shared/auth.ts";
import { errorResponse, handleError, jsonResponse } from "../_shared/http.ts";
import { payloadHash } from "../_shared/idempotency.ts";
import {
  ensureAllowedFields,
  optionalString,
  readJsonObject,
  requireBoolean,
  requireIsoDate,
  requireIsoTimestamp,
  requirePositiveAmount,
  requireString,
  requireUuid,
  requireVersion,
  ValidationError,
} from "../_shared/validation.ts";

export interface ApplyMutationArgs {
  operationId: string;
  operation: string;
  entityType: string;
  entityId: string;
  payload: Record<string, unknown>;
  payloadHash: string;
  sessionId: string;
  deviceId: string;
}

export interface AdminSyncHandlerDeps {
  sessionSecret: string;
  sessionStore: AdminSessionStore;
  applyMutation: (
    args: ApplyMutationArgs,
  ) => Promise<Record<string, unknown>>;
  now: () => Date;
}

export class AdminMutationError extends Error {
  constructor(
    readonly code: string,
    message: string,
    readonly statusCode = 400,
  ) {
    super(message);
    this.name = "AdminMutationError";
  }
}

const REQUEST_FIELDS = [
  "operation_id",
  "operation",
  "entity_type",
  "entity_id",
  "payload",
] as const;

const GROUP_FIELDS = [
  "id",
  "name",
  "description",
  "color",
  "icon",
  "sort_order",
  "is_archived",
  "created_at",
  "updated_at",
  "version",
  "expected_version",
  "move_debts_to_unassigned",
] as const;

const DEBT_FIELDS = [
  "id",
  "group_id",
  "title",
  "principal_amount",
  "due_date",
  "notes",
  "is_archived",
  "created_at",
  "updated_at",
  "version",
  "expected_version",
] as const;

const DEBT_BATCH_FIELDS = ["id", "debts"] as const;

const PAYMENT_FIELDS = [
  "id",
  "debt_id",
  "amount",
  "paid_at",
  "notes",
  "operation_id",
  "created_at",
] as const;

const ALLOWED_OPERATIONS: Readonly<Record<string, ReadonlySet<string>>> = {
  debt_group: new Set(["create", "update", "archive", "delete"]),
  debt: new Set(["create", "update", "archive", "delete"]),
  debt_batch: new Set(["create"]),
  payment: new Set(["payment_create"]),
};

export async function handleAdminSyncRequest(
  request: Request,
  deps: AdminSyncHandlerDeps,
): Promise<Response> {
  try {
    if (request.method !== "POST") {
      return errorResponse(
        "method_not_allowed",
        "Metode request tidak didukung.",
        405,
      );
    }

    const body = await readJsonObject(request);
    ensureAllowedFields(body, REQUEST_FIELDS);

    const operationId = requireUuid(body.operation_id, "operation_id");
    const operation = requireString(body.operation, "operation", {
      maxLength: 50,
    });
    const entityType = requireString(body.entity_type, "entity_type", {
      maxLength: 50,
    });
    const entityId = requireUuid(body.entity_id, "entity_id");
    const payload = requireObject(body.payload);
    validateMutation(
      operationId,
      operation,
      entityType,
      entityId,
      payload,
    );

    const authenticated = await requireAdminSession(request, {
      secret: deps.sessionSecret,
      store: deps.sessionStore,
      now: deps.now(),
    });
    const hash = await payloadHash(payload);
    const result = await deps.applyMutation({
      operationId,
      operation,
      entityType,
      entityId,
      payload,
      payloadHash: hash,
      sessionId: authenticated.claims.sessionId,
      deviceId: authenticated.claims.deviceId,
    });

    return mutationResponse(result);
  } catch (error) {
    if (error instanceof AdminMutationError) {
      return errorResponse(
        error.code,
        error.message,
        error.statusCode,
      );
    }

    return handleError(error);
  }
}

function mutationResponse(result: Record<string, unknown>): Response {
  const status = result.status;
  if (status === "applied") {
    return jsonResponse(result, 200);
  }

  if (status === "conflict") {
    return errorResponse(
      "version_conflict",
      "Data telah berubah di server. Pilih muat ulang atau pertahankan lokal.",
      409,
      result,
    );
  }

  if (status === "not_found") {
    return errorResponse(
      "not_found",
      "Data tidak ditemukan di server.",
      404,
      result,
    );
  }

  if (status === "failed") {
    const errorCode = result.error_code;
    const statusCode = errorCode === "version_conflict" ? 409 : 400;
    return errorResponse(
      typeof errorCode === "string" ? errorCode : "sync_failed",
      "Operasi sinkronisasi gagal.",
      statusCode,
      result,
    );
  }

  throw new AdminMutationError(
    "invalid_response",
    "Respons sinkronisasi tidak valid.",
    500,
  );
}

function validateMutation(
  operationId: string,
  operation: string,
  entityType: string,
  entityId: string,
  payload: Record<string, unknown>,
): void {
  const allowedOperations = ALLOWED_OPERATIONS[entityType];
  if (allowedOperations === undefined || !allowedOperations.has(operation)) {
    throw new ValidationError(
      "invalid_operation",
      "Operasi sinkronisasi tidak valid.",
    );
  }

  const payloadId = requireUuid(payload.id, "payload.id");
  if (payloadId !== entityId) {
    throw new ValidationError(
      "entity_id_mismatch",
      "Entity ID tidak konsisten.",
    );
  }

  switch (entityType) {
    case "debt_group":
      ensureAllowedFields(payload, GROUP_FIELDS);
      validateGroup(payload, operation);
      return;

    case "debt":
      ensureAllowedFields(payload, DEBT_FIELDS);
      validateDebt(payload, operation);
      return;

    case "debt_batch":
      ensureAllowedFields(payload, DEBT_BATCH_FIELDS);
      validateDebtBatch(payload);
      return;

    case "payment":
      ensureAllowedFields(payload, PAYMENT_FIELDS);
      validatePayment(payload, operationId);
      return;
  }
}

function validateGroup(
  payload: Record<string, unknown>,
  operation: string,
): void {
  if (operation === "create" || operation === "update") {
    requireString(payload.name, "name", { maxLength: 100 });
    optionalString(payload.description, "description", { maxLength: 1000 });
    optionalString(payload.color, "color", { maxLength: 7 });
    optionalString(payload.icon, "icon", { maxLength: 50 });
  }

  if (operation === "create") {
    optionalTimestamp(payload.created_at, "created_at");
    optionalTimestamp(payload.updated_at, "updated_at");
    optionalBoolean(payload.is_archived, "is_archived");
  }

  if (operation === "update") {
    optionalInteger(payload.sort_order, "sort_order", 0, 1_000_000);
    optionalBoolean(payload.is_archived, "is_archived");
    requireVersion(payload.expected_version, "expected_version");
  }

  if (operation === "archive") {
    requireVersion(payload.expected_version, "expected_version");
    requireBoolean(payload.is_archived, "is_archived");
  }

  if (operation === "delete") {
    requireVersion(payload.expected_version, "expected_version");
    optionalBoolean(
      payload.move_debts_to_unassigned,
      "move_debts_to_unassigned",
    );
  }
}

function validateDebt(
  payload: Record<string, unknown>,
  operation: string,
): void {
  if (operation === "create" || operation === "update") {
    requireString(payload.title, "title", { maxLength: 200 });
    requirePositiveAmount(payload.principal_amount, "principal_amount");
    optionalUuid(payload.group_id, "group_id");
    optionalDate(payload.due_date, "due_date");
    optionalString(payload.notes, "notes", { maxLength: 2000 });
  }

  if (operation === "create") {
    optionalTimestamp(payload.created_at, "created_at");
    optionalTimestamp(payload.updated_at, "updated_at");
    optionalBoolean(payload.is_archived, "is_archived");
  }

  if (operation === "update") {
    optionalBoolean(payload.is_archived, "is_archived");
    requireVersion(payload.expected_version, "expected_version");
  }

  if (operation === "archive") {
    requireVersion(payload.expected_version, "expected_version");
    requireBoolean(payload.is_archived, "is_archived");
  }

  if (operation === "delete") {
    requireVersion(payload.expected_version, "expected_version");
  }
}

function validateDebtBatch(payload: Record<string, unknown>): void {
  const debts = payload.debts;
  if (!Array.isArray(debts) || debts.length < 1 || debts.length > 50) {
    throw new ValidationError(
      "invalid_batch",
      "Jumlah hutang dalam batch harus 1-50.",
    );
  }

  const ids = new Set<string>();
  for (const [index, raw] of debts.entries()) {
    if (raw === null || typeof raw !== "object" || Array.isArray(raw)) {
      throw new ValidationError(
        "invalid_payload",
        `debts[${index}] harus berupa objek.`,
      );
    }

    const debt = raw as Record<string, unknown>;
    ensureAllowedFields(debt, DEBT_FIELDS);
    const id = requireUuid(debt.id, `debts[${index}].id`);
    if (ids.has(id)) {
      throw new ValidationError(
        "duplicate_debt_id",
        `ID hutang duplikat pada baris ${index + 1}.`,
      );
    }
    ids.add(id);
    validateDebt(debt, "create");
  }
}

function validatePayment(
  payload: Record<string, unknown>,
  operationId: string,
): void {
  requireUuid(payload.debt_id, "debt_id");
  requirePositiveAmount(payload.amount, "amount");
  requireIsoTimestamp(payload.paid_at, "paid_at");
  optionalString(payload.notes, "notes", { maxLength: 2000 });
  optionalTimestamp(payload.created_at, "created_at");

  const paymentOperationId = requireUuid(
    payload.operation_id,
    "operation_id",
  );
  if (paymentOperationId !== operationId) {
    throw new ValidationError(
      "operation_id_mismatch",
      "Operation ID pembayaran tidak konsisten.",
    );
  }
}

function requireObject(value: unknown): Record<string, unknown> {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new ValidationError("invalid_payload", "payload harus berupa objek.");
  }

  return value as Record<string, unknown>;
}

function optionalTimestamp(value: unknown, field: string): void {
  if (value !== null && value !== undefined) {
    requireIsoTimestamp(value, field);
  }
}

function optionalDate(value: unknown, field: string): void {
  if (value !== null && value !== undefined && value !== "") {
    requireIsoDate(value, field);
  }
}

function optionalBoolean(value: unknown, field: string): void {
  if (value !== null && value !== undefined) {
    requireBoolean(value, field);
  }
}

function optionalUuid(value: unknown, field: string): void {
  if (value !== null && value !== undefined && value !== "") {
    requireUuid(value, field);
  }
}

function optionalInteger(
  value: unknown,
  field: string,
  minimum: number,
  maximum: number,
): void {
  if (value === null || value === undefined) {
    return;
  }

  if (
    typeof value !== "number" ||
    !Number.isSafeInteger(value) ||
    value < minimum ||
    value > maximum
  ) {
    throw new ValidationError(
      "invalid_integer",
      `${field} harus berupa integer ${minimum}-${maximum}.`,
    );
  }
}
