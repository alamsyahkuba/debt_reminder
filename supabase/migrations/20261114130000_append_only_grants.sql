-- Supabase's default privileges can grant ALL on new public tables to
-- service_role. Payments and audit logs are append-only by product policy, so
-- remove mutation rights explicitly even for the trusted backend role.
--
-- The Edge Functions only insert payments/audit rows; payment updates are
-- rejected by the append-only trigger and are not part of any admin mutation.

revoke update, delete, truncate on table public.payments from service_role;
revoke update, delete, truncate on table public.audit_logs from service_role;
