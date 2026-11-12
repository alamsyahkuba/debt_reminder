import { AdminAuthError } from "./auth.ts";
import { IdempotencyError } from "./idempotency.ts";
import { ValidationError } from "./validation.ts";

const JSON_CONTENT_TYPE = "application/json; charset=utf-8";

export interface ApiErrorBody {
  error: {
    code: string;
    message: string;
    details?: unknown;
  };
}

export function jsonResponse(
  body: unknown,
  status = 200,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": JSON_CONTENT_TYPE },
  });
}

export function errorResponse(
  code: string,
  message: string,
  status = 400,
  details?: unknown,
): Response {
  const body: ApiErrorBody = {
    error: details === undefined
      ? { code, message }
      : { code, message, details },
  };

  return jsonResponse(body, status);
}

export function handleError(error: unknown): Response {
  if (error instanceof AdminAuthError) {
    return errorResponse(error.code, error.message, 401);
  }

  if (error instanceof ValidationError) {
    return errorResponse(error.code, error.message, 400, error.details);
  }

  if (error instanceof IdempotencyError) {
    if (
      error.code === "payload_mismatch" ||
      error.code === "operation_already_completed"
    ) {
      return errorResponse(error.code, error.message, 409);
    }

    if (error.code === "invalid_payload") {
      return errorResponse(error.code, error.message, 400);
    }

    return errorResponse(error.code, error.message, 500);
  }

  // Never expose internal exception messages or stack traces to clients.
  return errorResponse(
    "internal_error",
    "Terjadi kesalahan pada server.",
    500,
  );
}
