/**
 * Input validation shared by admin Edge Functions.
 *
 * Rules mirror the database constraints. Amounts are positive safe integers
 * in rupiah; dates use ISO-8601 with an explicit timezone.
 */

export const MAX_SAFE_RUPIAH = 9007199254740991;
const DEFAULT_MAX_BODY_BYTES = 64 * 1024;
const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const ISO_DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;
const ISO_TIMESTAMP_PATTERN =
  /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?(?:Z|[+-]\d{2}:\d{2})$/;

export class ValidationError extends Error {
  constructor(
    readonly code: string,
    message: string,
    readonly details?: Record<string, unknown>,
  ) {
    super(message);
    this.name = "ValidationError";
  }
}

export function requireObject(
  value: unknown,
  field = "payload",
): Record<string, unknown> {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new ValidationError(
      "invalid_payload",
      `${field} harus berupa objek.`,
    );
  }

  return value as Record<string, unknown>;
}

export function ensureAllowedFields(
  payload: Record<string, unknown>,
  allowedFields: readonly string[],
): void {
  const allowed = new Set(allowedFields);
  const unknownFields = Object.keys(payload).filter((key) => !allowed.has(key));

  if (unknownFields.length > 0) {
    throw new ValidationError(
      "unknown_fields",
      "Payload memuat field yang tidak diizinkan.",
      { fields: unknownFields.sort() },
    );
  }
}

export function requireUuid(value: unknown, field: string): string {
  if (typeof value !== "string" || !UUID_PATTERN.test(value)) {
    throw new ValidationError("invalid_uuid", `${field} harus berupa UUID.`);
  }

  return value.toLowerCase();
}

export function requireString(
  value: unknown,
  field: string,
  options: { minLength?: number; maxLength?: number; trim?: boolean } = {},
): string {
  const minLength = options.minLength ?? 1;
  const maxLength = options.maxLength ?? 200;
  const trim = options.trim ?? true;

  if (typeof value !== "string") {
    throw new ValidationError("invalid_string", `${field} harus berupa teks.`);
  }

  const normalized = trim ? value.trim() : value;

  if (
    normalized.length < minLength ||
    normalized.length > maxLength
  ) {
    throw new ValidationError(
      "invalid_string",
      `${field} harus memiliki panjang ${minLength}-${maxLength} karakter.`,
    );
  }

  return normalized;
}

export function optionalString(
  value: unknown,
  field: string,
  options: { maxLength?: number } = {},
): string | null {
  if (value === null || value === undefined) {
    return null;
  }

  const maxLength = options.maxLength ?? 2000;

  if (typeof value !== "string") {
    throw new ValidationError("invalid_string", `${field} harus berupa teks.`);
  }

  const normalized = value.trim();
  if (normalized.length === 0) {
    return null;
  }

  if (normalized.length > maxLength) {
    throw new ValidationError(
      "invalid_string",
      `${field} maksimal ${maxLength} karakter.`,
    );
  }

  return normalized;
}

export function requirePositiveAmount(value: unknown, field: string): number {
  if (
    typeof value !== "number" ||
    !Number.isSafeInteger(value) ||
    value <= 0 ||
    value > MAX_SAFE_RUPIAH
  ) {
    throw new ValidationError(
      "invalid_amount",
      `${field} harus berupa integer rupiah positif.`,
    );
  }

  return value;
}

export function requireVersion(value: unknown, field = "version"): number {
  if (
    typeof value !== "number" ||
    !Number.isSafeInteger(value) ||
    value < 1
  ) {
    throw new ValidationError(
      "invalid_version",
      `${field} harus berupa integer minimal 1.`,
    );
  }

  return value;
}

export function requireIsoDate(value: unknown, field: string): string {
  if (typeof value !== "string" || !ISO_DATE_PATTERN.test(value)) {
    throw new ValidationError(
      "invalid_date",
      `${field} harus menggunakan format YYYY-MM-DD.`,
    );
  }

  const parsed = new Date(`${value}T00:00:00.000Z`);
  if (
    Number.isNaN(parsed.getTime()) ||
    parsed.toISOString().slice(0, 10) !== value
  ) {
    throw new ValidationError("invalid_date", `${field} bukan tanggal valid.`);
  }

  return value;
}

export function requireIsoTimestamp(value: unknown, field: string): string {
  if (typeof value !== "string" || !ISO_TIMESTAMP_PATTERN.test(value)) {
    throw new ValidationError(
      "invalid_timestamp",
      `${field} harus berupa timestamp ISO-8601 dengan timezone.`,
    );
  }

  if (Number.isNaN(Date.parse(value))) {
    throw new ValidationError(
      "invalid_timestamp",
      `${field} bukan timestamp valid.`,
    );
  }

  return value;
}

export function requireBoolean(value: unknown, field: string): boolean {
  if (typeof value !== "boolean") {
    throw new ValidationError(
      "invalid_boolean",
      `${field} harus berupa boolean.`,
    );
  }

  return value;
}

export async function readJsonObject(
  request: Request,
  maxBytes = DEFAULT_MAX_BODY_BYTES,
): Promise<Record<string, unknown>> {
  const contentLength = request.headers.get("content-length");
  if (contentLength !== null) {
    const declaredSize = Number(contentLength);
    if (!Number.isSafeInteger(declaredSize) || declaredSize > maxBytes) {
      throw new ValidationError(
        "payload_too_large",
        "Payload terlalu besar.",
      );
    }
  }

  let text: string;
  try {
    text = await request.text();
  } catch {
    throw new ValidationError("invalid_payload", "Payload tidak dapat dibaca.");
  }

  if (new TextEncoder().encode(text).length > maxBytes) {
    throw new ValidationError("payload_too_large", "Payload terlalu besar.");
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch {
    throw new ValidationError("invalid_json", "Payload bukan JSON valid.");
  }

  return requireObject(parsed);
}
