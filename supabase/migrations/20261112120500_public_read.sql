-- Public read-only RPCs for the revised product.
--
-- All business fields are public. Internal metadata (version, operation_id,
-- sync state, admin/audit/session data) is not returned. Base tables remain
-- inaccessible to anon; these functions are security definer and execute as
-- their owner.

create or replace function public.public_debt_groups()
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
language sql
stable
security definer
set search_path = ''
as $function$
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
  order by g.sort_order, g.name;
$function$;

create or replace function public.public_debts()
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
language sql
stable
security definer
set search_path = ''
as $function$
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
  order by d.due_date nulls last, d.created_at;
$function$;

create or replace function public.public_payments()
returns table (
  id uuid,
  debt_id uuid,
  amount bigint,
  paid_at timestamptz,
  notes text,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $function$
  select
    p.id,
    p.debt_id,
    p.amount,
    p.paid_at,
    p.notes,
    p.created_at
  from public.payments p
  order by p.paid_at, p.created_at;
$function$;

revoke all on function public.public_debt_groups()
  from public, anon, authenticated;
revoke all on function public.public_debts()
  from public, anon, authenticated;
revoke all on function public.public_payments()
  from public, anon, authenticated;

grant execute on function public.public_debt_groups() to anon;
grant execute on function public.public_debts() to anon;
grant execute on function public.public_payments() to anon;
