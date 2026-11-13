/**
 * PIN hashing and validation.
 *
 * PIN is a six-digit numeric secret. Hashing uses PBKDF2-HMAC-SHA256 with a
 * random per-PIN salt and a server-side pepper from the Edge Function secret.
 * The stored format is:
 *
 *   pbkdf2_sha256$<iterations>$<salt-base64url>$<hash-base64url>
 */

import { base64UrlEncode } from "./crypto.ts";

export const PIN_LENGTH = 6;
export const PIN_HASH_ALGORITHM = "pbkdf2_sha256";
export const PIN_HASH_ITERATIONS = 210_000;
const MIN_ITERATIONS = 10_000;
const MAX_ITERATIONS = 1_000_000;
const SALT_BYTES = 16;
const HASH_BITS = 256;
const PIN_PATTERN = /^\d{6}$/;

export class PinValidationError extends Error {
  constructor(message = "PIN harus terdiri dari 6 digit angka.") {
    super(message);
    this.name = "PinValidationError";
  }
}

export function validatePin(value: unknown): string {
  if (typeof value !== "string" || !PIN_PATTERN.test(value)) {
    throw new PinValidationError();
  }

  return value;
}

export async function hashPin(
  pin: string,
  pepper: string,
  salt?: Uint8Array,
): Promise<string> {
  validatePin(pin);
  validatePepper(pepper);

  const saltBytes = salt ?? crypto.getRandomValues(new Uint8Array(SALT_BYTES));
  if (saltBytes.length < 8) {
    throw new PinValidationError("Salt PIN tidak valid.");
  }

  const hash = await derivePinHash(pin, pepper, saltBytes, PIN_HASH_ITERATIONS);

  return [
    PIN_HASH_ALGORITHM,
    PIN_HASH_ITERATIONS.toString(),
    base64UrlEncode(saltBytes),
    base64UrlEncode(hash),
  ].join("$");
}

export async function verifyPin(
  pin: string,
  storedHash: string,
  pepper: string,
): Promise<boolean> {
  validatePin(pin);
  validatePepper(pepper);

  const parsed = parseStoredHash(storedHash);
  if (parsed === null) {
    return false;
  }

  const candidate = await derivePinHash(
    pin,
    pepper,
    parsed.salt,
    parsed.iterations,
  );

  return constantTimeEqual(candidate, parsed.hash);
}

export function constantTimeEqual(
  left: Uint8Array,
  right: Uint8Array,
): boolean {
  if (left.length !== right.length) {
    return false;
  }

  let difference = 0;
  for (let index = 0; index < left.length; index++) {
    difference |= left[index]! ^ right[index]!;
  }

  return difference === 0;
}

export function constantTimeStringEqual(left: string, right: string): boolean {
  return constantTimeEqual(
    new TextEncoder().encode(left),
    new TextEncoder().encode(right),
  );
}

export function validatePepper(pepper: string): void {
  if (pepper.trim().length < 32) {
    throw new PinValidationError(
      "ADMIN_PIN_PEPPER minimal 32 karakter.",
    );
  }
}

export function validateInitialPin(value: string | undefined): string | null {
  if (value === undefined || value.trim().length === 0) {
    return null;
  }

  return validatePin(value);
}

async function derivePinHash(
  pin: string,
  pepper: string,
  salt: Uint8Array,
  iterations: number,
): Promise<Uint8Array> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(`${pin}\u0000${pepper}`),
    "PBKDF2",
    false,
    ["deriveBits"],
  );

  const saltBuffer = new ArrayBuffer(salt.length);
  new Uint8Array(saltBuffer).set(salt);

  const bits = await crypto.subtle.deriveBits(
    {
      name: "PBKDF2",
      hash: "SHA-256",
      salt: saltBuffer,
      iterations,
    },
    key,
    HASH_BITS,
  );

  return new Uint8Array(bits);
}

function parseStoredHash(
  storedHash: string,
): { iterations: number; salt: Uint8Array; hash: Uint8Array } | null {
  const parts = storedHash.split("$");
  if (parts.length !== 4) {
    return null;
  }

  const [algorithm, iterationsText, saltText, hashText] = parts;
  if (algorithm !== PIN_HASH_ALGORITHM || iterationsText === undefined) {
    return null;
  }

  const iterations = Number(iterationsText);
  if (
    !Number.isSafeInteger(iterations) ||
    iterations < MIN_ITERATIONS ||
    iterations > MAX_ITERATIONS ||
    saltText === undefined ||
    hashText === undefined
  ) {
    return null;
  }

  try {
    return {
      iterations,
      salt: decodeBase64Url(saltText),
      hash: decodeBase64Url(hashText),
    };
  } catch {
    return null;
  }
}

function decodeBase64Url(value: string): Uint8Array {
  if (!/^[A-Za-z0-9_-]+$/.test(value)) {
    throw new Error("invalid base64url");
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
