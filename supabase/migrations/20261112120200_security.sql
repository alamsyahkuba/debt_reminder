-- Security policy: Option A from the owner decision.
--
-- There is NO anonymous or ordinary-user read path in v1. All cloud reads and
-- writes go through admin Edge Functions using the service role after a
-- server-side session check. Therefore:
--   * RLS is enabled everywhere.
--   * No anon/authenticated policies are created.
--   * The anon and authenticated roles lose schema usage and table grants.
--   * Only service_role receives explicit business-table grants.
--
-- Do not add a public view or RPC without an owner decision and a new migration.

alter table public.customers enable row level security;
alter table public.debt_groups enable row level security;
alter table public.debts enable row level security;
alter table public.payments enable row level security;
alter table public.admin_settings enable row level security;
alter table public.audit_logs enable row level security;
alter table public.admin_sessions enable row level security;
alter table public.operation_registry enable row level security;

comment on table public.customers is
  'RLS enabled. Option A: no anon/authenticated access.';
comment on table public.debt_groups is
  'RLS enabled. Option A: no anon/authenticated access.';
comment on table public.debts is
  'RLS enabled. Option A: no anon/authenticated access.';
comment on table public.payments is
  'RLS enabled, append-only. Option A: no anon/authenticated access.';
comment on table public.admin_settings is
  'RLS enabled. Never accessible to anon/authenticated.';
comment on table public.audit_logs is
  'RLS enabled, append-only. Never accessible to anon/authenticated.';
comment on table public.admin_sessions is
  'RLS enabled. Never accessible to anon/authenticated.';
comment on table public.operation_registry is
  'RLS enabled. Service-role idempotency registry only.';

-- Remove Supabase default API exposure for this project. PostgreSQL grants
-- USAGE on schema public to PUBLIC by default, so revoke that too before
-- granting the minimum schema access back to trusted server roles.
revoke all on schema public from public;
revoke all on schema public from anon;
revoke all on schema public from authenticated;

grant usage on schema public to postgres;
grant usage on schema public to authenticator;
grant usage on schema public to service_role;

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

-- Business tables. Delete is granted only where the approved archive/delete
-- policy may need it; payments and audit logs are append-only.
grant select, insert, update, delete on table public.customers to service_role;
grant select, insert, update, delete on table public.debt_groups to service_role;
grant select, insert, update, delete on table public.debts to service_role;
grant select, insert on table public.payments to service_role;
grant select, insert on table public.audit_logs to service_role;
grant select, insert, update on table public.admin_settings to service_role;
grant select, insert, update, delete on table public.admin_sessions to service_role;
grant select, insert, update, delete on table public.operation_registry to service_role;

-- There are intentionally zero policies on every table. service_role bypasses
-- RLS; anon and authenticated have neither schema usage nor table grants.
