begin;

alter table public.orders
  add column if not exists cancellation_request_status text not null default 'none',
  add column if not exists cancellation_request_reason text not null default '',
  add column if not exists cancellation_requested_at timestamptz,
  add column if not exists cancellation_reviewed_at timestamptz,
  add column if not exists cancellation_reviewed_by uuid references auth.users(id) on delete set null;

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'orders_cancellation_request_status_check') then
    alter table public.orders add constraint orders_cancellation_request_status_check
      check (cancellation_request_status in ('none','pending','approved','denied'));
  end if;
end $$;

create or replace function public.customer_request_order_cancellation(p_order_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_owner uuid;
  v_status text;
  v_payment_status text;
  v_request_status text;
begin
  if v_user_id is null then raise exception 'Authentication required'; end if;
  if length(trim(coalesce(p_reason,''))) < 3 or length(p_reason) > 500 then
    raise exception 'Choose a cancellation reason and keep it under 500 characters';
  end if;

  select user_id,status,payment_status,cancellation_request_status
    into v_owner,v_status,v_payment_status,v_request_status
  from public.orders where id=p_order_id for update;
  if not found or v_owner <> v_user_id then raise exception 'Order not found'; end if;
  if v_status <> 'pending_confirmation' then raise exception 'Cancellation requests are only available before order confirmation'; end if;
  if v_payment_status = 'collected' then raise exception 'This order has a collected payment. Contact the store for help.'; end if;
  if v_request_status = 'pending' then raise exception 'A cancellation request is already awaiting admin approval'; end if;

  update public.orders
    set cancellation_request_status='pending',
        cancellation_request_reason=left(trim(p_reason),500),
        cancellation_requested_at=now(),
        cancellation_reviewed_at=null,
        cancellation_reviewed_by=null,
        updated_at=now()
  where id=p_order_id;
end;
$$;

create or replace function public.admin_review_order_cancellation(
  p_order_id uuid,
  p_approve boolean,
  p_note text default ''
) returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_order public.orders%rowtype;
  v_item record;
begin
  if not public.is_frostly_order_manager() then raise exception 'Order manager access required'; end if;
  select * into v_order from public.orders where id=p_order_id for update;
  if not found then raise exception 'Order not found'; end if;
  if v_order.cancellation_request_status <> 'pending' then raise exception 'No pending cancellation request'; end if;

  if not p_approve then
    update public.orders
      set cancellation_request_status='denied',
          cancellation_reviewed_at=now(),
          cancellation_reviewed_by=auth.uid(),
          updated_at=now()
    where id=p_order_id;
    insert into public.admin_audit_logs(actor_id,action,entity_type,entity_id,details)
    values(auth.uid(),'order_cancellation_denied','order',p_order_id,jsonb_build_object('reason',v_order.cancellation_request_reason,'note',left(coalesce(p_note,''),500)));
    return;
  end if;

  if v_order.status <> 'pending_confirmation' then raise exception 'Order is no longer awaiting confirmation'; end if;
  if v_order.payment_status = 'collected' then raise exception 'This order has a collected payment and needs manual review'; end if;

  for v_item in
    select product_id,quantity from public.order_items
    where order_id=p_order_id and product_id is not null
  loop
    update public.products set stock_quantity=stock_quantity+v_item.quantity,updated_at=now()
      where id=v_item.product_id;
    insert into public.inventory_movements(product_id,changed_by,quantity_delta,reason)
      values(v_item.product_id,auth.uid(),v_item.quantity,'Admin approved customer cancellation '||p_order_id::text);
  end loop;

  update public.orders
    set status='cancelled',
        cancellation_reason=left(v_order.cancellation_request_reason,500),
        cancellation_request_status='approved',
        cancellation_reviewed_at=now(),
        cancellation_reviewed_by=auth.uid(),
        updated_at=now()
  where id=p_order_id;

  update public.order_status_history
    set note=left('Admin approved customer cancellation: '||v_order.cancellation_request_reason,500)
  where id=(select id from public.order_status_history where order_id=p_order_id and new_status='cancelled' order by created_at desc limit 1);

  insert into public.admin_audit_logs(actor_id,action,entity_type,entity_id,details)
  values(auth.uid(),'order_cancellation_approved','order',p_order_id,jsonb_build_object('reason',v_order.cancellation_request_reason,'note',left(coalesce(p_note,''),500)));
end;
$$;

create or replace function public.prevent_order_progress_during_cancellation_review()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
begin
  if old.cancellation_request_status='pending'
     and new.cancellation_request_status='pending'
     and new.status is distinct from old.status then
    raise exception 'Review the pending cancellation request before changing order status';
  end if;
  return new;
end;
$$;

drop trigger if exists orders_prevent_progress_during_cancellation_review on public.orders;
create trigger orders_prevent_progress_during_cancellation_review
before update of status on public.orders
for each row execute function public.prevent_order_progress_during_cancellation_review();

revoke all on function public.customer_request_order_cancellation(uuid,text) from public,anon;
revoke all on function public.customer_cancel_order(uuid) from public,anon,authenticated;
revoke all on function public.admin_review_order_cancellation(uuid,boolean,text) from public,anon;
grant execute on function public.customer_request_order_cancellation(uuid,text) to authenticated;
grant execute on function public.admin_review_order_cancellation(uuid,boolean,text) to authenticated;

commit;