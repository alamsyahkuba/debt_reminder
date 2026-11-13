import {
  DEFAULT_PIN_LOCK_SECONDS,
  DEFAULT_PIN_MAX_ATTEMPTS,
  handleAdminPinRequest,
} from "./handler.ts";
import { SupabaseAdminPinStore } from "./supabase_store.ts";
import { createSupabaseAdminClient } from "../_shared/supabase_client.ts";
import { validateInitialPin, validatePepper } from "../_shared/pin.ts";

const supabaseUrl = requireEnv("SUPABASE_URL");
const serviceRoleKey = requireEnv("SUPABASE_SERVICE_ROLE_KEY");
const sessionSecret = requireSecret("ADMIN_SESSION_JWT_SECRET");
const pinPepper = requireSecret("ADMIN_PIN_PEPPER");
const initialPin = validateInitialPin(
  Deno.env.get("ADMIN_INITIAL_PIN") ?? undefined,
);

validatePepper(pinPepper);

const store = new SupabaseAdminPinStore(
  createSupabaseAdminClient(supabaseUrl, serviceRoleKey),
);

Deno.serve((request) =>
  handleAdminPinRequest(request, {
    store,
    sessionSecret,
    pinPepper,
    initialPin,
    maxAttempts: readPositiveInteger(
      "ADMIN_PIN_MAX_ATTEMPTS",
      DEFAULT_PIN_MAX_ATTEMPTS,
      1,
      20,
    ),
    lockSeconds: readPositiveInteger(
      "ADMIN_PIN_LOCK_SECONDS",
      DEFAULT_PIN_LOCK_SECONDS,
      30,
      86_400,
    ),
    now: () => new Date(),
  })
);

function requireEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) {
    throw new Error(`${name} wajib diisi.`);
  }

  return value;
}

function requireSecret(name: string): string {
  const value = requireEnv(name);
  if (value.length < 32) {
    throw new Error(`${name} minimal 32 karakter.`);
  }

  return value;
}

function readPositiveInteger(
  name: string,
  fallback: number,
  minimum: number,
  maximum: number,
): number {
  const raw = Deno.env.get(name)?.trim();
  if (!raw) {
    return fallback;
  }

  const value = Number(raw);
  if (
    !Number.isSafeInteger(value) ||
    value < minimum ||
    value > maximum
  ) {
    throw new Error(`${name} harus berupa integer ${minimum}-${maximum}.`);
  }

  return value;
}
