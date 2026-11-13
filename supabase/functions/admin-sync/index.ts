import {
  AdminMutationError,
  type ApplyMutationArgs,
  handleAdminSyncRequest,
} from "./handler.ts";
import { SupabaseAdminSessionStore } from "../_shared/supabase_admin_session_store.ts";
import { createSupabaseAdminClient } from "../_shared/supabase_client.ts";

const supabaseUrl = requireEnv("SUPABASE_URL");
const serviceRoleKey = requireEnv("SUPABASE_SERVICE_ROLE_KEY");
const sessionSecret = requireSecret("ADMIN_SESSION_JWT_SECRET");

const client = createSupabaseAdminClient(supabaseUrl, serviceRoleKey);
const sessionStore = new SupabaseAdminSessionStore(client);

Deno.serve((request) =>
  handleAdminSyncRequest(request, {
    sessionSecret,
    sessionStore,
    now: () => new Date(),
    applyMutation: (args) => applyMutation(client, args),
  })
);

async function applyMutation(
  supabase: ReturnType<typeof createSupabaseAdminClient>,
  args: ApplyMutationArgs,
): Promise<Record<string, unknown>> {
  const { data, error } = await supabase.rpc("admin_apply_mutation", {
    p_operation_id: args.operationId,
    p_operation: args.operation,
    p_entity_type: args.entityType,
    p_entity_id: args.entityId,
    p_payload: args.payload,
    p_payload_hash: args.payloadHash,
    p_session_id: args.sessionId,
    p_device_id: args.deviceId,
  });

  if (error) {
    throw mapRpcError(error);
  }

  if (Array.isArray(data)) {
    const first = data[0];
    if (first !== null && typeof first === "object") {
      return first as Record<string, unknown>;
    }
  }

  if (data !== null && typeof data === "object") {
    return data as Record<string, unknown>;
  }

  throw new AdminMutationError(
    "invalid_response",
    "Respons server tidak valid.",
    500,
  );
}

function mapRpcError(error: {
  code?: string;
  message?: string;
}): AdminMutationError {
  const code = error.code ?? "";

  if (
    code === "P0001" ||
    code === "22023" ||
    code === "23503" ||
    code === "23514" ||
    code === "22P02"
  ) {
    return new AdminMutationError(
      "validation_error",
      error.message ?? "Data mutasi tidak valid.",
      400,
    );
  }

  if (code === "40001") {
    return new AdminMutationError(
      "retryable",
      "Server sedang sibuk. Coba lagi.",
      503,
    );
  }

  return new AdminMutationError(
    "server_error",
    "Operasi sinkronisasi gagal di server.",
    500,
  );
}

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
