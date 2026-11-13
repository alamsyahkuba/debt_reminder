/** Shared service-role Supabase client for Edge Functions. */

import { createClient, type SupabaseClient } from "@supabase/supabase-js";

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
