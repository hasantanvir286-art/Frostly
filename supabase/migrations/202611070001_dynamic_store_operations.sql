-- Enforce dashboard-configured store availability and minimum order totals
-- for every order path, including direct RPC calls.
create or replace function public.enforce_store_order_rules()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_page_builder jsonb;
  v_minimum numeric := 0;
begin
  if public.is_frostly_admin() then
    return new;
  end if;

  select page_builder into v_page_builder
  from public.site_settings
  where id = 'main';

  if coalesce(v_page_builder #>> '{operations,store_open}', 'true') = 'false' then
    raise exception 'The store is temporarily not accepting orders';
  end if;

  v_minimum := greatest(
    0,
    coalesce(nullif(v_page_builder #>> '{operations,minimum_order_bdt}', '')::numeric, 0)
  );
  if coalesce(new.subtotal_bdt, 0) < v_minimum then
    raise exception 'Order subtotal must be at least ৳ %', trim(to_char(v_minimum, 'FM999999999')); 
  end if;

  return new;
end;
$$;

drop trigger if exists orders_enforce_store_rules on public.orders;
create trigger orders_enforce_store_rules
before insert on public.orders
for each row execute function public.enforce_store_order_rules();
