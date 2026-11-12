/**
 * Authentication for admin-enrolled read-only devices.
 *
 * The token is opaque, returned once during enrollment, and stored by the
 * server only as SHA-256. It permits pull requests only; it never permits
 * mutations. Anon access remains disabled.
 */

import { randomToken, sha256Hex } from "./crypto.ts";

export const DEVICE_TOKEN_PREFIX = "dr_dev_";
const DEVICE_TOKEN_PATTERN = /^dr_dev_[A-Za-z0-9_-]{43}$/;

export type DeviceAuthErrorCode =
  | "missing_device_token"
  | "invalid_device_token"
  | "device_revoked"
  | "device_expired";

export class DeviceAuthError extends Error {
  constructor(
    readonly code: DeviceAuthErrorCode,
    message = "Akses perangkat tidak valid.",
  ) {
    super(message);
    this.name = "DeviceAuthError";
  }
}

export interface ReadDeviceRecord {
  id: string;
  name: string;
  deviceId: string;
  expiresAt: string;
  revokedAt: string | null;
  lastSeenAt: string | null;
}

export interface ReadDeviceStore {
  findByTokenHash(tokenHash: string): Promise<ReadDeviceRecord | null>;
  touch(tokenHash: string, now: Date): Promise<void>;
}

export interface RequireReadDeviceOptions {
  store: ReadDeviceStore;
  now?: Date;
}

export interface AuthenticatedReadDevice {
  device: ReadDeviceRecord;
  tokenHash: string;
}

export function generateDeviceToken(): string {
  return randomToken(DEVICE_TOKEN_PREFIX);
}

export function hashDeviceToken(token: string): Promise<string> {
  return sha256Hex(token);
}

export function getDeviceToken(request: Request): string {
  const header = request.headers.get("authorization");

  if (!header) {
    throw new DeviceAuthError(
      "missing_device_token",
      "Header Authorization perangkat wajib diisi.",
    );
  }

  const match = /^Bearer\s+(\S+)$/i.exec(header.trim());
  const token = match?.[1];

  if (!token || !DEVICE_TOKEN_PATTERN.test(token)) {
    throw new DeviceAuthError(
      "invalid_device_token",
      "Token perangkat tidak valid.",
    );
  }

  return token;
}

export async function requireReadDevice(
  request: Request,
  options: RequireReadDeviceOptions,
): Promise<AuthenticatedReadDevice> {
  const token = getDeviceToken(request);
  const tokenHash = await hashDeviceToken(token);
  const now = options.now ?? new Date();
  const device = await options.store.findByTokenHash(tokenHash);

  if (!device) {
    throw new DeviceAuthError(
      "invalid_device_token",
      "Token perangkat tidak valid.",
    );
  }

  if (device.revokedAt !== null) {
    throw new DeviceAuthError(
      "device_revoked",
      "Akses perangkat sudah dicabut.",
    );
  }

  const expiresAt = Date.parse(device.expiresAt);
  if (Number.isNaN(expiresAt) || expiresAt <= now.getTime()) {
    throw new DeviceAuthError(
      "device_expired",
      "Akses perangkat sudah kedaluwarsa.",
    );
  }

  await options.store.touch(tokenHash, now);
  return { device, tokenHash };
}
