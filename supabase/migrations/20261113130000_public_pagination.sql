-- Paginated public read RPCs for incremental pull.
--
-- Cursors are keyset-based on (updated_at, id) for mutable rows and
-- (created_at, id) for append-only payments. Public rows still expose only
-- approved business fields; version/internal metadata remains private.

create or replace function public.public_debt_groups_page(
  p_after_updated_at timestamptz default null,
  p_after_id uuid default null,
  p_limit integer default 100
)
returns table (
  id uuid,
  name text,
  description text,
  color text,
  icon text,
  sort_order integer,
  is_archived boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $function$
begin
  if p_limit is null or p_limit not between 1 and 500 then
    raise exception using errcode = '22023', message = 'limit tidak valid';
  end if;

  if (p_after_updated_at is null) <> (p_after_id is null) then
    raise exception using errcode = '22023', message = 'cursor tidak valid';
  end if;

  return query
  select
    g.id,
    g.name,
    g.description,
    g.color,
    g.icon,
    g.sort_order,
    g.is_archived,
    g.created_at,
    g.updated_at
  from public.debt_groups g
  where p_after_updated_at is null
    or (g.updated_at, g.id) > (p_after_updated_at, p_after_id)
  order by g.updated_at, g.id
  limit p_limit;
end;
$function$;

create or replace function public.public_debts_page(
  p_after_updated_at timestamptz default null,
  p_after_id uuid default null,
  p_limit integer default 100
)
returns table (
  id uuid,
  group_id uuid,
  group_name text,
  title text,
  principal_amount bigint,
  due_date date,
  notes text,
  is_archived boolean,
  created_at timestamptz,
  updated_at timestamptz,
  paid_amount bigint,
  outstanding_amount bigint,
  status text
)
language plpgsql
stable
security definer
set search_path = ''
as $function$
begin
  if p_limit is null or p_limit not between 1 and 500 then
    raise exception using errcode = '22023', message = 'limit tidak valid';
  end if;

  if (p_after_updated_at is null) <> (p_after_id is null) then
    raise exception using errcode = '22023', message = 'cursor tidak valid';
  end if;

  return query
  with paid as (
    select
      p.debt_id,
      sum(p.amount)::bigint as paid_amount
    from public.payments p
    group by p.debt_id
  )
  select
    d.id,
    d.group_id,
    g.name as group_name,
    d.title,
    d.principal_amount,
    d.due_date,
    d.notes,
    d.is_archived,
    d.created_at,
    d.updated_at,
    coalesce(paid.paid_amount, 0)::bigint as paid_amount,
    greatest(
      d.principal_amount - coalesce(paid.paid_amount, 0),
      0::bigint
    )::bigint as outstanding_amount,
    case
      when coalesce(paid.paid_amount, 0) >= d.principal_amount then 'paid'
      when d.due_date is not null and d.due_date < current_date then 'overdue'
      when coalesce(paid.paid_amount, 0) > 0 then 'partial'
      else 'unpaid'
    end::text as status
  from public.debts d
  left join public.debt_groups g on g.id = d.group_id
  left join paid on paid.debt_id = d.id
  where p_after_updated_at is null
    or (d.updated_at, d.id) > (p_after_updated_at, p_after_id)
  order by d.updated_at, d.id
  limit p_limit;
end;
$function$;

create or replace function public.public_payments_page(
  p_after_created_at timestamptz default null,
  p_after_id uuid default null,
  p_limit integer default 100
)
returns table (
  id uuid,
  debt_id uuid,
  amount bigint,
  paid_at timestamptz,
  notes text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $function$
begin
  if p_limit is null or p_limit not between 1 and 500 then
    raise exception using errcode = '22023', message = 'limit tidak valid';
  end if;

  if (p_after_created_at is null) <> (p_after_id is null) then
    raise exception using errcode = '22023', message = 'cursor tidak valid';
  end if;

  return query
  select
    p.id,
    p.debt_id,
    p.amount,
    p.paid_at,
    p.notes,
    p.created_at
  from public.payments p
  where p_after_created_at is null
    or (p.created_at, p.id) > (p_after_created_at, p_after_id)
  order by p.created_at, p.id
  limit p_limit;
end;
$function$;

revoke all on function public.public_debt_groups_page(timestamptz, uuid, integer)
  from public, anon, authenticated;
revoke all on function public.public_debts_page(timestamptz, uuid, integer)
  from public, anon, authenticated;
revoke all on function public.public_payments_page(timestamptz, uuid, integer)
  from public, anon, authenticated;

grant execute on function public.public_debt_groups_page(timestamptz, uuid, integer)
  to anon;
grant execute on function public.public_debts_page(timestamptz, uuid, integer)
  to anon;
grant execute on function public.public_payments_page(timestamptz, uuid, integer)
  to anon;
