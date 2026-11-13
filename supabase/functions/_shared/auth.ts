/**
 * Server-side admin session verification.
 *
 * Token contract (issued in Sprint 06):
 * - JWT HS256 signed with ADMIN_SESSION_JWT_SECRET (>= 32 characters).
 * - iss = debt-reminder
 * - aud = debt-reminder-admin
 * - sub = admin subject
 * - role = admin
 * - session_id = UUID row in public.admin_sessions
 * - device_id = opaque device identifier
 * - iat / exp (Unix seconds), maximum lifetime 15 minutes.
 *
 * The server stores only SHA-256(token) in admin_sessions. The client never
 * sees the signing secret and the service role key never leaves the server.
 */

import { base64UrlEncode, sha256Hex } from "./crypto.ts";

export const ADMIN_TOKEN_ISSUER = "debt-reminder";
export const ADMIN_TOKEN_AUDIENCE = "debt-reminder-admin";
export const ADMIN_TOKEN_TTL_SECONDS = 15 * 60;
export const ADMIN_SUBJECT = "admin";
export const ADMIN_TOKEN_HEADER = "x-admin-session";

const CLOCK_SKEW_SECONDS = 60;
const MIN_SECRET_LENGTH = 32;
const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export type AdminAuthErrorCode =
  | "missing_token"
  | "invalid_token"
  | "expired_token"
  | "session_revoked";

export class AdminAuthError extends Error {
  constructor(
    readonly code: AdminAuthErrorCode,
    message = "Sesi admin tidak valid.",
  ) {
    super(message);
    this.name = "AdminAuthError";
  }
}

export interface AdminTokenClaims {
  subject: string;
  role: "admin";
  sessionId: string;
  deviceId: string;
  issuedAt: number;
  expiresAt: number;
}

export interface AdminSessionStore {
  /**
   * Returns true only when the session exists, is not revoked, is unexpired,
   * and matches the device claim in the token.
   */
  isActive(tokenHash: string, deviceId: string, now: Date): Promise<boolean>;
  /** Records last_used_at without extending the token or session expiry. */
  touch(tokenHash: string, now: Date): Promise<void>;
}

export interface RequireAdminSessionOptions {
  secret: string;
  store: AdminSessionStore;
  now?: Date;
}

export interface AuthenticatedAdmin {
  claims: AdminTokenClaims;
  tokenHash: string;
}

export function getBearerToken(request: Request): string {
  const header = request.headers.get("authorization");

  if (!header) {
    throw new AdminAuthError(
      "missing_token",
      "Header Authorization wajib diisi.",
    );
  }

  const match = /^Bearer\s+(\S+)$/i.exec(header.trim());
  const token = match?.[1];

  if (!token) {
    throw new AdminAuthError(
      "invalid_token",
      "Format token admin tidak valid.",
    );
  }

  return token;
}

/**
 * Reads the custom admin session header.
 *
 * Supabase's Edge Function gateway verifies the `Authorization` header as a
 * Supabase JWT. The custom admin token must therefore use a separate header so
 * the gateway can validate the anon key without rejecting the admin session.
 */
export function getAdminToken(request: Request): string {
  const header = request.headers.get(ADMIN_TOKEN_HEADER);

  if (!header) {
    throw new AdminAuthError(
      "missing_token",
      "Header sesi admin wajib diisi.",
    );
  }

  const token = header.trim();
  if (token.length === 0 || /\s/.test(token)) {
    throw new AdminAuthError("invalid_token", "Token admin tidak valid.");
  }

  return token;
}

export async function requireAdminSession(
  request: Request,
  options: RequireAdminSessionOptions,
): Promise<AuthenticatedAdmin> {
  const token = getAdminToken(request);
  const now = options.now ?? new Date();
  const claims = await verifyAdminToken(token, options.secret, now);
  const tokenHash = await hashToken(token);

  if (!(await options.store.isActive(tokenHash, claims.deviceId, now))) {
    throw new AdminAuthError(
      "session_revoked",
      "Sesi admin sudah berakhir atau dicabut.",
    );
  }

  await options.store.touch(tokenHash, now);

  return { claims, tokenHash };
}

export async function verifyAdminToken(
  token: string,
  secret: string,
  now: Date = new Date(),
): Promise<AdminTokenClaims> {
  if (secret.length < MIN_SECRET_LENGTH) {
    throw new AdminAuthError(
      "invalid_token",
      "Konfigurasi sesi admin tidak valid.",
    );
  }

  const parts = token.split(".");
  if (parts.length !== 3) {
    throw new AdminAuthError("invalid_token", "Token admin tidak valid.");
  }

  const [encodedHeader, encodedPayload, encodedSignature] = parts;
  if (
    encodedHeader === undefined ||
    encodedPayload === undefined ||
    encodedSignature === undefined
  ) {
    throw new AdminAuthError("invalid_token", "Token admin tidak valid.");
  }

  const header = decodeJsonObject(encodedHeader, "invalid_token");

  if (header.alg !== "HS256" || header.typ !== "JWT") {
    throw new AdminAuthError("invalid_token", "Algoritma token tidak valid.");
  }

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["verify"],
  );

  const signatureBytes = decodeBase64Url(encodedSignature);
  if (signatureBytes.length !== 32) {
    throw new AdminAuthError("invalid_token", "Token admin tidak valid.");
  }

  // Copy into a regular ArrayBuffer so the Web Crypto BufferSource type is
  // satisfied without relying on SharedArrayBuffer.
  const signature = new ArrayBuffer(signatureBytes.length);
  new Uint8Array(signature).set(signatureBytes);

  const signedContent = new TextEncoder().encode(
    `${encodedHeader}.${encodedPayload}`,
  );
  const signatureValid = await crypto.subtle.verify(
    { name: "HMAC" },
    key,
    signature,
    signedContent,
  );

  if (!signatureValid) {
    throw new AdminAuthError("invalid_token", "Token admin tidak valid.");
  }

  const payload = decodeJsonObject(encodedPayload, "invalid_token");
  const nowSeconds = Math.floor(now.getTime() / 1000);

  if (
    payload.iss !== ADMIN_TOKEN_ISSUER ||
    payload.aud !== ADMIN_TOKEN_AUDIENCE
  ) {
    throw new AdminAuthError("invalid_token", "Token admin tidak valid.");
  }

  if (payload.role !== "admin") {
    throw new AdminAuthError("invalid_token", "Token admin tidak valid.");
  }

  if (
    typeof payload.sub !== "string" ||
    payload.sub.trim().length === 0 ||
    payload.sub.length > 200
  ) {
    throw new AdminAuthError("invalid_token", "Token admin tidak valid.");
  }

  if (
    typeof payload.session_id !== "string" ||
    !UUID_PATTERN.test(payload.session_id)
  ) {
    throw new AdminAuthError("invalid_token", "Token admin tidak valid.");
  }

  if (
    typeof payload.device_id !== "string" ||
    payload.device_id.trim().length === 0 ||
    payload.device_id.length > 200
  ) {
    throw new AdminAuthError("invalid_token", "Token admin tidak valid.");
  }

  if (
    typeof payload.iat !== "number" ||
    !Number.isSafeInteger(payload.iat) ||
    typeof payload.exp !== "number" ||
    !Number.isSafeInteger(payload.exp)
  ) {
    throw new AdminAuthError("invalid_token", "Token admin tidak valid.");
  }

  if (payload.iat > nowSeconds + CLOCK_SKEW_SECONDS) {
    throw new AdminAuthError("invalid_token", "Token admin tidak valid.");
  }

  if (payload.exp <= nowSeconds) {
    throw new AdminAuthError("expired_token", "Sesi admin sudah kedaluwarsa.");
  }

  if (
    payload.exp <= payload.iat ||
    payload.exp - payload.iat > ADMIN_TOKEN_TTL_SECONDS + CLOCK_SKEW_SECONDS
  ) {
    throw new AdminAuthError("invalid_token", "Token admin tidak valid.");
  }

  return {
    subject: payload.sub,
    role: "admin",
    sessionId: payload.session_id.toLowerCase(),
    deviceId: payload.device_id,
    issuedAt: payload.iat,
    expiresAt: payload.exp,
  };
}

export function hashToken(token: string): Promise<string> {
  return sha256Hex(token);
}

export interface SignAdminTokenOptions {
  secret: string;
  sessionId: string;
  deviceId: string;
  subject?: string;
  issuedAt?: Date;
  ttlSeconds?: number;
}

export interface SignedAdminToken {
  token: string;
  expiresAt: Date;
}

export async function signAdminToken(
  options: SignAdminTokenOptions,
): Promise<SignedAdminToken> {
  if (options.secret.length < MIN_SECRET_LENGTH) {
    throw new AdminAuthError(
      "invalid_token",
      "Konfigurasi sesi admin tidak valid.",
    );
  }

  if (!UUID_PATTERN.test(options.sessionId)) {
    throw new AdminAuthError("invalid_token", "Session id tidak valid.");
  }

  const deviceId = options.deviceId.trim();
  if (deviceId.length === 0 || deviceId.length > 200) {
    throw new AdminAuthError("invalid_token", "Device id tidak valid.");
  }

  const subject = (options.subject ?? ADMIN_SUBJECT).trim();
  if (subject.length === 0 || subject.length > 200) {
    throw new AdminAuthError("invalid_token", "Subject admin tidak valid.");
  }

  const ttlSeconds = options.ttlSeconds ?? ADMIN_TOKEN_TTL_SECONDS;
  if (
    !Number.isSafeInteger(ttlSeconds) ||
    ttlSeconds < 60 ||
    ttlSeconds > ADMIN_TOKEN_TTL_SECONDS
  ) {
    throw new AdminAuthError(
      "invalid_token",
      "Masa berlaku token tidak valid.",
    );
  }

  const issuedAt = options.issuedAt ?? new Date();
  const iat = Math.floor(issuedAt.getTime() / 1000);
  const exp = iat + ttlSeconds;
  const encodedHeader = encodeJson({ alg: "HS256", typ: "JWT" });
  const encodedPayload = encodeJson({
    iss: ADMIN_TOKEN_ISSUER,
    aud: ADMIN_TOKEN_AUDIENCE,
    sub: subject,
    role: "admin",
    session_id: options.sessionId.toLowerCase(),
    device_id: deviceId,
    iat,
    exp,
  });

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(options.secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(`${encodedHeader}.${encodedPayload}`),
  );

  return {
    token: `${encodedHeader}.${encodedPayload}.${
      base64UrlEncode(new Uint8Array(signature))
    }`,
    expiresAt: new Date(exp * 1000),
  };
}

function encodeJson(value: unknown): string {
  return base64UrlEncode(
    new TextEncoder().encode(JSON.stringify(value)),
  );
}

function decodeJsonObject(
  value: string,
  code: AdminAuthErrorCode,
): Record<string, unknown> {
  let parsed: unknown;

  try {
    const bytes = decodeBase64Url(value);
    const text = new TextDecoder("utf-8", { fatal: true }).decode(bytes);
    parsed = JSON.parse(text);
  } catch {
    throw new AdminAuthError(code, "Token admin tidak valid.");
  }

  if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new AdminAuthError(code, "Token admin tidak valid.");
  }

  return parsed as Record<string, unknown>;
}

function decodeBase64Url(value: string): Uint8Array {
  if (!/^[A-Za-z0-9_-]+$/.test(value)) {
    throw new AdminAuthError("invalid_token", "Token admin tidak valid.");
  }

  const base64 = value.replace(/-/g, "+").replace(/_/g, "/");
  const padded = base64.padEnd(Math.ceil(base64.length / 4) * 4, "=");
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);

  for (let index = 0; index < binary.length; index++) {
    bytes[index] = binary.charCodeAt(index);
  }

  return bytes;
}
