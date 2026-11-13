/**
 * Admin PIN Edge Function handler.
 *
 * Kept separate from the Deno entry point so the security behaviour can be
 * unit-tested with an in-memory store. The handler never returns PIN hashes,
 * tokens other than the newly issued session token, or internal errors.
 */

import {
  ADMIN_TOKEN_TTL_SECONDS,
  type AdminSessionStore,
  hashToken,
  requireAdminSession,
  signAdminToken,
} from "../_shared/auth.ts";
import { errorResponse, handleError, jsonResponse } from "../_shared/http.ts";
import {
  constantTimeStringEqual,
  hashPin,
  PIN_HASH_ALGORITHM,
  PinValidationError,
  validatePin,
  verifyPin as verifyPinHash,
} from "../_shared/pin.ts";
import {
  ensureAllowedFields,
  readJsonObject,
  requireString,
  ValidationError,
} from "../_shared/validation.ts";

export const DEFAULT_PIN_MAX_ATTEMPTS = 5;
export const DEFAULT_PIN_LOCK_SECONDS = 15 * 60;

const ACTION_VERIFY = "verify";
const ACTION_CHANGE = "change";
const ACTION_LOGOUT = "logout";
const ALLOWED_FIELDS = [
  "action",
  "pin",
  "current_pin",
  "new_pin",
  "device_id",
] as const;

export interface AdminPinAttempt {
  allowed: boolean;
  hasPin: boolean;
  retryAfterSeconds: number;
  failedAttemptCount: number;
}

export interface AdminPinHash {
  hash: string;
  algorithm: string;
}

export interface AdminAuditEntry {
  action: string;
  entityType: string;
  entityId: string | null;
  metadata: Record<string, unknown>;
}

export interface AdminPinStore extends AdminSessionStore {
  beginPinAttempt(options: {
    now: Date;
    maxAttempts: number;
    lockSeconds: number;
  }): Promise<AdminPinAttempt>;
  getPinHash(): Promise<AdminPinHash | null>;
  setPinHash(hash: string, algorithm: string): Promise<void>;
  resetPinAttempts(): Promise<void>;
  createSession(options: {
    sessionId: string;
    tokenHash: string;
    deviceId: string;
    expiresAt: Date;
    now: Date;
  }): Promise<void>;
  revokeSession(tokenHash: string, now: Date): Promise<boolean>;
  revokeOtherSessions(tokenHash: string, now: Date): Promise<number>;
  appendAudit(entry: AdminAuditEntry): Promise<void>;
}

export interface AdminPinHandlerDeps {
  store: AdminPinStore;
  sessionSecret: string;
  pinPepper: string;
  initialPin: string | null;
  maxAttempts: number;
  lockSeconds: number;
  now: () => Date;
}

export class InvalidPinError extends Error {
  constructor() {
    super("PIN tidak valid.");
    this.name = "InvalidPinError";
  }
}

export class RateLimitError extends Error {
  constructor(readonly retryAfterSeconds: number) {
    super("Terlalu banyak percobaan PIN.");
    this.name = "RateLimitError";
  }
}

export class PinNotConfiguredError extends Error {
  constructor() {
    super("PIN admin belum dikonfigurasi.");
    this.name = "PinNotConfiguredError";
  }
}

export async function handleAdminPinRequest(
  request: Request,
  deps: AdminPinHandlerDeps,
): Promise<Response> {
  try {
    if (request.method !== "POST") {
      return errorResponse(
        "method_not_allowed",
        "Metode request tidak didukung.",
        405,
      );
    }

    const payload = await readJsonObject(request);
    ensureAllowedFields(payload, ALLOWED_FIELDS);
    const action = requireString(payload.action, "action", {
      maxLength: 32,
    });
    const now = deps.now();

    switch (action) {
      case ACTION_VERIFY:
        return await verifyPin(payload, now, deps);
      case ACTION_CHANGE:
        return await changePin(request, payload, now, deps);
      case ACTION_LOGOUT:
        return await logout(request, now, deps);
      default:
        throw new ValidationError(
          "invalid_action",
          "Aksi admin tidak valid.",
        );
    }
  } catch (error) {
    if (error instanceof RateLimitError) {
      return errorResponse(
        "rate_limited",
        "Terlalu banyak percobaan PIN. Coba lagi nanti.",
        429,
        { retry_after_seconds: error.retryAfterSeconds },
      );
    }

    if (error instanceof InvalidPinError) {
      return errorResponse("invalid_pin", "PIN tidak valid.", 401);
    }

    if (error instanceof PinNotConfiguredError) {
      return errorResponse(
        "pin_not_configured",
        "PIN admin belum dikonfigurasi di server.",
        503,
      );
    }

    if (error instanceof PinValidationError) {
      return errorResponse("invalid_pin_format", error.message, 400);
    }

    return handleError(error);
  }
}

async function verifyPin(
  payload: Record<string, unknown>,
  now: Date,
  deps: AdminPinHandlerDeps,
): Promise<Response> {
  const pin = validatePin(payload.pin);
  const deviceId = requireString(payload.device_id, "device_id", {
    maxLength: 200,
  });

  const attempt = await deps.store.beginPinAttempt({
    now,
    maxAttempts: deps.maxAttempts,
    lockSeconds: deps.lockSeconds,
  });
  if (!attempt.allowed) {
    throw new RateLimitError(attempt.retryAfterSeconds);
  }

  let stored = await deps.store.getPinHash();
  if (stored === null || stored.algorithm === "uninitialized") {
    if (deps.initialPin === null) {
      throw new PinNotConfiguredError();
    }

    if (!constantTimeStringEqual(pin, deps.initialPin)) {
      await appendAuditBestEffort(deps, {
        action: "admin_pin_bootstrap_failed",
        entityType: "admin_settings",
        entityId: null,
        metadata: { device_id: deviceId },
      });
      throw new InvalidPinError();
    }

    const hash = await hashPin(pin, deps.pinPepper);
    await deps.store.setPinHash(hash, PIN_HASH_ALGORITHM);
    stored = { hash, algorithm: PIN_HASH_ALGORITHM };
  } else if (!(await verifyPinHash(pin, stored.hash, deps.pinPepper))) {
    await appendAuditBestEffort(deps, {
      action: "admin_pin_failed",
      entityType: "admin_settings",
      entityId: null,
      metadata: { device_id: deviceId },
    });
    throw new InvalidPinError();
  }

  await deps.store.resetPinAttempts();

  const sessionId = crypto.randomUUID();
  const signed = await signAdminToken({
    secret: deps.sessionSecret,
    sessionId,
    deviceId,
    issuedAt: now,
  });
  const tokenHash = await hashToken(signed.token);

  await deps.store.createSession({
    sessionId,
    tokenHash,
    deviceId,
    expiresAt: signed.expiresAt,
    now,
  });

  await appendAuditBestEffort(deps, {
    action: "admin_pin_verified",
    entityType: "admin_session",
    entityId: sessionId,
    metadata: { device_id: deviceId },
  });

  return jsonResponse({
    token: signed.token,
    token_type: "Bearer",
    expires_at: signed.expiresAt.toISOString(),
    expires_in_seconds: ADMIN_TOKEN_TTL_SECONDS,
  });
}

async function changePin(
  request: Request,
  payload: Record<string, unknown>,
  now: Date,
  deps: AdminPinHandlerDeps,
): Promise<Response> {
  const authenticated = await requireAdminSession(request, {
    secret: deps.sessionSecret,
    store: deps.store,
    now,
  });
  const currentPin = validatePin(payload.current_pin);
  const newPin = validatePin(payload.new_pin);

  if (constantTimeStringEqual(currentPin, newPin)) {
    throw new ValidationError(
      "pin_unchanged",
      "PIN baru harus berbeda dari PIN sebelumnya.",
    );
  }

  const attempt = await deps.store.beginPinAttempt({
    now,
    maxAttempts: deps.maxAttempts,
    lockSeconds: deps.lockSeconds,
  });
  if (!attempt.allowed) {
    throw new RateLimitError(attempt.retryAfterSeconds);
  }

  const stored = await deps.store.getPinHash();
  if (stored === null || stored.algorithm === "uninitialized") {
    throw new PinNotConfiguredError();
  }

  if (!(await verifyPinHash(currentPin, stored.hash, deps.pinPepper))) {
    await appendAuditBestEffort(deps, {
      action: "admin_pin_change_failed",
      entityType: "admin_settings",
      entityId: null,
      metadata: {
        device_id: authenticated.claims.deviceId,
        session_id: authenticated.claims.sessionId,
      },
    });
    throw new InvalidPinError();
  }

  const newHash = await hashPin(newPin, deps.pinPepper);
  await deps.store.setPinHash(newHash, PIN_HASH_ALGORITHM);
  await deps.store.resetPinAttempts();
  const revokedSessions = await deps.store.revokeOtherSessions(
    authenticated.tokenHash,
    now,
  );

  await appendAuditBestEffort(deps, {
    action: "admin_pin_changed",
    entityType: "admin_settings",
    entityId: null,
    metadata: {
      device_id: authenticated.claims.deviceId,
      revoked_sessions: revokedSessions,
    },
  });

  return jsonResponse({
    status: "ok",
    revoked_sessions: revokedSessions,
  });
}

async function logout(
  request: Request,
  now: Date,
  deps: AdminPinHandlerDeps,
): Promise<Response> {
  const authenticated = await requireAdminSession(request, {
    secret: deps.sessionSecret,
    store: deps.store,
    now,
  });
  await deps.store.revokeSession(authenticated.tokenHash, now);

  await appendAuditBestEffort(deps, {
    action: "admin_logout",
    entityType: "admin_session",
    entityId: authenticated.claims.sessionId,
    metadata: { device_id: authenticated.claims.deviceId },
  });

  return jsonResponse({ status: "ok" });
}

async function appendAuditBestEffort(
  deps: AdminPinHandlerDeps,
  entry: AdminAuditEntry,
): Promise<void> {
  try {
    await deps.store.appendAudit(entry);
  } catch (error) {
    // Audit must never expose secrets; log only that persistence failed.
    console.error("admin_audit_append_failed", {
      action: entry.action,
      error: error instanceof Error ? error.message : "unknown",
    });
  }
}
