-- Ensure order managers, admins, and superadmins can update order status.
-- Older installations may still have the original admin-only function from migration 001.

create or replace function public.admin_set_order_status(
  p_order_id uuid,
  p_status text,
  p_note text default ''
) returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_current text;
begin
  if not public.is_frostly_order_manager() then
    raise exception 'Order manager access required';
  end if;

  if p_status not in ('pending_confirmation','confirmed','preparing','packed','out_for_delivery','delivered','cancelled') then
    raise exception 'Invalid order status';
  end if;

  select status into v_current
  from public.orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'Order not found';
  end if;
  if v_current = p_status then
    return;
  end if;

  if not (
    (v_current = 'pending_confirmation' and p_status in ('confirmed','cancelled')) or
    (v_current = 'confirmed' and p_status in ('preparing','cancelled')) or
    (v_current = 'preparing' and p_status in ('packed','cancelled')) or
    (v_current = 'packed' and p_status = 'out_for_delivery') or
    (v_current = 'out_for_delivery' and p_status in ('delivered','cancelled'))
  ) then
    raise exception 'Order status transition is not allowed';
  end if;

  update public.orders
  set status = p_status,
      cancellation_reason = case when p_status = 'cancelled' then left(coalesce(p_note,''),500) else cancellation_reason end
  where id = p_order_id;

  if length(coalesce(p_note,'')) > 0 then
    update public.order_status_history
    set note = left(p_note,500)
    where order_id = p_order_id
      and new_status = p_status
      and created_at = (
        select max(created_at)
        from public.order_status_history
        where order_id = p_order_id
      );
  end if;

  insert into public.admin_audit_logs(actor_id,action,entity_type,entity_id,details)
  values(auth.uid(),'order_status_changed','order',p_order_id,jsonb_build_object('status',p_status));
end;
$$;

revoke all on function public.admin_set_order_status(uuid,text,text) from public, anon;
grant execute on function public.admin_set_order_status(uuid,text,text) to authenticated;
