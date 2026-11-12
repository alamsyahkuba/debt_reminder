/** Small crypto helpers shared by admin and read-only device tokens. */

export async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );

  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

export function randomToken(prefix: string, byteLength = 32): string {
  if (byteLength < 16) {
    throw new RangeError("Token minimal 16 byte.");
  }

  const bytes = crypto.getRandomValues(new Uint8Array(byteLength));
  return `${prefix}${base64UrlEncode(bytes)}`;
}

export function base64UrlEncode(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }

  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}
