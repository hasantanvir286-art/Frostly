-- Record admin stock changes in one transaction with their inventory ledger entry.
create or replace function public.admin_adjust_inventory(
  p_product_id uuid,
  p_new_quantity integer,
  p_reason text default 'Admin stock adjustment'
)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_previous integer;
begin
  if not public.is_frostly_admin() then
    raise exception 'Administrator access required';
  end if;
  if p_new_quantity is null or p_new_quantity < 0 then
    raise exception 'Stock quantity must be zero or greater';
  end if;

  select stock_quantity into v_previous
  from public.products
  where id = p_product_id
  for update;
  if not found then
    raise exception 'Product not found';
  end if;

  if v_previous <> p_new_quantity then
    update public.products
    set stock_quantity = p_new_quantity,
        updated_at = now()
    where id = p_product_id;

    insert into public.inventory_movements(product_id, changed_by, quantity_delta, reason)
    values(p_product_id, auth.uid(), p_new_quantity - v_previous,
      coalesce(nullif(trim(p_reason), ''), 'Admin stock adjustment'));
  end if;
  return p_new_quantity;
end;
$$;

revoke all on function public.admin_adjust_inventory(uuid, integer, text) from public;
grant execute on function public.admin_adjust_inventory(uuid, integer, text) to authenticated;
