-- Shared trigger helpers live outside the API-exposed schema.
create schema if not exists private;

revoke all on schema private from public;
revoke all on schema private from anon;
revoke all on schema private from authenticated;
grant usage on schema private to service_role;

-- Bump updated_at and version on mutable business rows.
create or replace function private.set_updated_at_and_version()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  new.updated_at := pg_catalog.now();
  new.version := old.version + 1;
  return new;
end;
$function$;

-- Bump updated_at on server-owned metadata tables.
create or replace function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  new.updated_at := pg_catalog.now();
  return new;
end;
$function$;

-- Reject updates/deletes for append-only tables such as payments and audit logs.
create or replace function private.reject_mutation()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  raise exception using
    errcode = 'restrict_violation',
    message = pg_catalog.format(
      'Tabel %s bersifat append-only dan tidak boleh diubah atau dihapus.',
      tg_table_name
    );
end;
$function$;

revoke all on function private.set_updated_at_and_version() from public;
revoke all on function private.set_updated_at_and_version() from anon;
revoke all on function private.set_updated_at_and_version() from authenticated;

revoke all on function private.set_updated_at() from public;
revoke all on function private.set_updated_at() from anon;
revoke all on function private.set_updated_at() from authenticated;

revoke all on function private.reject_mutation() from public;
revoke all on function private.reject_mutation() from anon;
revoke all on function private.reject_mutation() from authenticated;
