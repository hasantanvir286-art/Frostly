-- Keep the store-open guard but remove the minimum-order threshold.
-- Existing trigger remains active and continues rejecting orders while the store is closed.
create or replace function public.enforce_store_order_rules()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_page_builder jsonb;
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

  return new;
end;
$$;