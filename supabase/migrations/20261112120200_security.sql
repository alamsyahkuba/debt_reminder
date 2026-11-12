-- Public read-only security model (revised 12 November 2026).
--
-- * All business fields are public through explicit read-only RPCs.
-- * Anon gets schema usage and execute on public read RPCs only.
-- * Anon gets no direct table SELECT/INSERT/UPDATE/DELETE.
-- * Base tables keep RLS enabled with no anon/authenticated policies.
-- * Admin mutations use service_role through Edge Functions after session auth.
-- * Internal tables remain service-role only.

alter table public.debt_groups enable row level security;
alter table public.debts enable row level security;
alter table public.payments enable row level security;
alter table public.admin_settings enable row level security;
alter table public.audit_logs enable row level security;
alter table public.admin_sessions enable row level security;
alter table public.operation_registry enable row level security;

comment on table public.debt_groups is
  'RLS enabled. Public read via RPC only; no direct anon access.';
comment on table public.debts is
  'RLS enabled. Public read via RPC only; no direct anon access.';
comment on table public.payments is
  'RLS enabled, append-only. Public read via RPC only.';
comment on table public.admin_settings is
  'RLS enabled. Never accessible to anon/authenticated.';
comment on table public.audit_logs is
  'RLS enabled, append-only. Never accessible to anon/authenticated.';
comment on table public.admin_sessions is
  'RLS enabled. Never accessible to anon/authenticated.';
comment on table public.operation_registry is
  'RLS enabled. Service-role idempotency registry only.';

-- Remove Supabase default API exposure, then grant only schema usage to anon
-- so it can resolve the public read RPCs. No table grants are given to anon.
revoke all on schema public from public;
revoke all on schema public from anon;
revoke all on schema public from authenticated;

grant usage on schema public to postgres;
grant usage on schema public to authenticator;
grant usage on schema public to service_role;
grant usage on schema public to anon;

revoke all on all tables in schema public from anon;
revoke all on all tables in schema public from authenticated;
revoke all on all sequences in schema public from anon;
revoke all on all sequences in schema public from authenticated;

-- Future objects owned by postgres must not be auto-granted to API roles.
alter default privileges for role postgres in schema public
  revoke all on tables from anon;
alter default privileges for role postgres in schema public
  revoke all on tables from authenticated;
alter default privileges for role postgres in schema public
  revoke all on sequences from anon;
alter default privileges for role postgres in schema public
  revoke all on sequences from authenticated;
alter default privileges for role postgres in schema public
  revoke execute on functions from public;
alter default privileges for role postgres in schema public
  revoke execute on functions from anon;
alter default privileges for role postgres in schema public
  revoke execute on functions from authenticated;

-- Business tables are service-role only at the table level. Public access is
-- granted separately on the read-only RPCs in the public_read migration.
grant select, insert, update, delete on table public.debt_groups to service_role;
grant select, insert, update, delete on table public.debts to service_role;
grant select, insert on table public.payments to service_role;
grant select, insert on table public.audit_logs to service_role;
grant select, insert, update on table public.admin_settings to service_role;
grant select, insert, update, delete on table public.admin_sessions to service_role;
grant select, insert, update, delete on table public.operation_registry to service_role;

-- Zero anon/authenticated policies are intentional. Anon can only execute the
-- explicit public read RPCs granted in 20261112120500_public_read.sql.
