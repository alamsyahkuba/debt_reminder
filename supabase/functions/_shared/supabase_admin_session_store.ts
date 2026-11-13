/** Supabase-backed admin session store for mutation endpoints. */

import type { SupabaseClient } from "@supabase/supabase-js";

import type { AdminSessionStore } from "./auth.ts";

export class SupabaseAdminSessionStore implements AdminSessionStore {
  constructor(private readonly client: SupabaseClient) {}

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
}
