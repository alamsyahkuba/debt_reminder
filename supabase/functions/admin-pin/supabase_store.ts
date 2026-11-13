/** Supabase-backed store for the admin PIN Edge Function. */

import { createClient, type SupabaseClient } from "@supabase/supabase-js";

import type {
  AdminAuditEntry,
  AdminPinAttempt,
  AdminPinHash,
  AdminPinStore,
} from "./handler.ts";

const ADMIN_SETTINGS_ID = "00000000-0000-0000-0000-000000000001";

export function createSupabaseAdminClient(
  url: string,
  serviceRoleKey: string,
): SupabaseClient {
  return createClient(url, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
  });
}

export class SupabaseAdminPinStore implements AdminPinStore {
  constructor(private readonly client: SupabaseClient) {}

  async beginPinAttempt(options: {
    now: Date;
    maxAttempts: number;
    lockSeconds: number;
  }): Promise<AdminPinAttempt> {
    const { data, error } = await this.client.rpc("begin_admin_pin_attempt", {
      p_now: options.now.toISOString(),
      p_max_attempts: options.maxAttempts,
      p_lock_seconds: options.lockSeconds,
    });

    if (error) {
      throw new Error("begin_admin_pin_attempt_failed");
    }

    const row = firstRow(data);
    return {
      allowed: row?.allowed === true,
      hasPin: row?.has_pin === true,
      retryAfterSeconds: toInteger(row?.retry_after_seconds),
      failedAttemptCount: toInteger(row?.failed_attempt_count),
    };
  }

  async getPinHash(): Promise<AdminPinHash | null> {
    const { data, error } = await this.client
      .from("admin_settings")
      .select("pin_hash, pin_hash_algorithm")
      .eq("id", ADMIN_SETTINGS_ID)
      .maybeSingle();

    if (error) {
      throw new Error("admin_settings_read_failed");
    }

    if (!data) {
      return null;
    }

    const row = data as Record<string, unknown>;
    if (
      typeof row.pin_hash !== "string" ||
      typeof row.pin_hash_algorithm !== "string"
    ) {
      throw new Error("admin_settings_invalid");
    }

    return {
      hash: row.pin_hash,
      algorithm: row.pin_hash_algorithm,
    };
  }

  async setPinHash(hash: string, algorithm: string): Promise<void> {
    const { error } = await this.client.rpc("set_admin_pin_hash", {
      p_pin_hash: hash,
      p_algorithm: algorithm,
    });

    if (error) {
      throw new Error("set_admin_pin_hash_failed");
    }
  }

  async resetPinAttempts(): Promise<void> {
    const { error } = await this.client.rpc("reset_admin_pin_attempts");

    if (error) {
      throw new Error("reset_admin_pin_attempts_failed");
    }
  }

  async createSession(options: {
    sessionId: string;
    tokenHash: string;
    deviceId: string;
    expiresAt: Date;
    now: Date;
  }): Promise<void> {
    const { error } = await this.client.rpc("create_admin_session", {
      p_session_id: options.sessionId,
      p_token_hash: options.tokenHash,
      p_device_id: options.deviceId,
      p_expires_at: options.expiresAt.toISOString(),
      p_now: options.now.toISOString(),
    });

    if (error) {
      throw new Error("create_admin_session_failed");
    }
  }

  async isActive(
    tokenHash: string,
    deviceId: string,
    now: Date,
  ): Promise<boolean> {
    const { data, error } = await this.client.rpc(
      "is_admin_session_active",
      {
        p_token_hash: tokenHash,
        p_device_id: deviceId,
        p_now: now.toISOString(),
      },
    );

    if (error) {
      throw new Error("is_admin_session_active_failed");
    }

    return data === true;
  }

  async touch(tokenHash: string, now: Date): Promise<void> {
    const { error } = await this.client.rpc("touch_admin_session", {
      p_token_hash: tokenHash,
      p_now: now.toISOString(),
    });

    if (error) {
      throw new Error("touch_admin_session_failed");
    }
  }

  async revokeSession(tokenHash: string, now: Date): Promise<boolean> {
    const { data, error } = await this.client.rpc("revoke_admin_session", {
      p_token_hash: tokenHash,
      p_now: now.toISOString(),
    });

    if (error) {
      throw new Error("revoke_admin_session_failed");
    }

    return data === true;
  }

  async revokeOtherSessions(tokenHash: string, now: Date): Promise<number> {
    const { data, error } = await this.client.rpc(
      "revoke_other_admin_sessions",
      {
        p_token_hash: tokenHash,
        p_now: now.toISOString(),
      },
    );

    if (error) {
      throw new Error("revoke_other_admin_sessions_failed");
    }

    return toInteger(data);
  }

  async appendAudit(entry: AdminAuditEntry): Promise<void> {
    const { error } = await this.client.rpc("append_audit_log", {
      p_actor_type: "admin",
      p_action: entry.action,
      p_entity_type: entry.entityType,
      p_entity_id: entry.entityId,
      p_operation_id: null,
      p_metadata: entry.metadata,
    });

    if (error) {
      throw new Error("append_audit_log_failed");
    }
  }
}

function firstRow(data: unknown): Record<string, unknown> | null {
  if (Array.isArray(data)) {
    return data.length > 0 ? (data[0] as Record<string, unknown>) : null;
  }

  if (data !== null && typeof data === "object") {
    return data as Record<string, unknown>;
  }

  return null;
}

function toInteger(value: unknown): number {
  if (typeof value === "number" && Number.isSafeInteger(value)) {
    return value;
  }

  const parsed = Number(value);
  return Number.isSafeInteger(parsed) ? parsed : 0;
}
