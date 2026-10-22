-- Staff roles, server-enforced permissions, and superadmin user management.
-- Run after migrations 202610200001 through 202610220009.

alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles add constraint profiles_role_check
  check (role in ('customer','delivery','superadmin','admin','ordermanager','stockmanager','catalogmanager','deliverymanager','settingsmanager'));

create or replace function public.is_frostly_superadmin()
returns boolean language sql stable security definer set search_path = public, pg_temp
as $$ select exists (select 1 from public.profiles where id=auth.uid() and role='superadmin') $$;

create or replace function public.is_frostly_admin()
returns boolean language sql stable security definer set search_path = public, pg_temp
as $$ select exists (select 1 from public.profiles where id=auth.uid() and role in ('superadmin','admin')) $$;

create or replace function public.is_frostly_staff()
returns boolean language sql stable security definer set search_path = public, pg_temp
as $$ select exists (select 1 from public.profiles where id=auth.uid() and role in ('superadmin','admin','ordermanager','stockmanager','catalogmanager','deliverymanager','settingsmanager')) $$;

create or replace function public.is_frostly_order_manager()
returns boolean language sql stable security definer set search_path = public, pg_temp
as $$ select exists (select 1 from public.profiles where id=auth.uid() and role in ('superadmin','admin','ordermanager')) $$;

create or replace function public.is_frostly_stock_manager()
returns boolean language sql stable security definer set search_path = public, pg_temp
as $$ select exists (select 1 from public.profiles where id=auth.uid() and role in ('superadmin','admin','stockmanager')) $$;

create or replace function public.is_frostly_catalog_manager()
returns boolean language sql stable security definer set search_path = public, pg_temp
as $$ select exists (select 1 from public.profiles where id=auth.uid() and role in ('superadmin','admin','catalogmanager')) $$;

create or replace function public.is_frostly_delivery_manager()
returns boolean language sql stable security definer set search_path = public, pg_temp
as $$ select exists (select 1 from public.profiles where id=auth.uid() and role in ('superadmin','admin','deliverymanager')) $$;

create or replace function public.is_frostly_settings_manager()
returns boolean language sql stable security definer set search_path = public, pg_temp
as $$ select exists (select 1 from public.profiles where id=auth.uid() and role in ('superadmin','admin','settingsmanager')) $$;

create or replace function public.prevent_profile_role_change()
returns trigger language plpgsql security definer set search_path = public, pg_temp
as $$ begin
  if new.role is distinct from old.role and coalesce(current_setting('frostly.authorized_role_change', true),'') <> 'yes' then
    raise exception 'Staff roles can only be changed through superadmin user management';
  end if;
  new.updated_at := now();
  return new;
end $$;

-- Promote the earliest existing admin exactly once, preserving a bootstrap account.
do $$ begin
  perform set_config('frostly.authorized_role_change','yes',true);
  update public.profiles
  set role = 'superadmin'
  where id = (select id from public.profiles where role='admin' order by created_at asc limit 1)
    and not exists (select 1 from public.profiles where role='superadmin');
end $$;

create or replace function public.superadmin_list_users()
returns table(user_id uuid, email text, full_name text, role text, created_at timestamptz, email_confirmed_at timestamptz)
language plpgsql stable security definer set search_path = public, auth, pg_temp
as $$ begin
  if not public.is_frostly_superadmin() then raise exception 'Superadmin access required'; end if;
  return query
    select u.id, u.email::text, p.full_name, p.role, u.created_at, u.email_confirmed_at
    from auth.users u join public.profiles p on p.id=u.id
    order by u.created_at desc;
end $$;

create or replace function public.superadmin_set_user_role(p_user_id uuid, p_role text)
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_old_role text;
begin
  if not public.is_frostly_superadmin() then raise exception 'Superadmin access required'; end if;
  if p_role not in ('customer','delivery','superadmin','admin','ordermanager','stockmanager','catalogmanager','deliverymanager','settingsmanager') then
    raise exception 'Unsupported account role';
  end if;
  if p_user_id is null then raise exception 'User is required'; end if;
  if p_user_id=auth.uid() and p_role<>'superadmin' then raise exception 'You cannot remove your own superadmin access'; end if;
  perform pg_advisory_xact_lock(hashtext('frostly-superadmin-role-change'));
  select role into v_old_role from public.profiles where id=p_user_id for update;
  if not found then raise exception 'User profile not found'; end if;
  if v_old_role='superadmin' and p_role<>'superadmin'
     and (select count(*) from public.profiles where role='superadmin') <= 1 then
    raise exception 'At least one superadmin must remain';
  end if;
  perform set_config('frostly.authorized_role_change','yes',true);
  update public.profiles set role=p_role, updated_at=now() where id=p_user_id;
  insert into public.admin_audit_logs(actor_id,action,entity_type,entity_id,details)
  values(auth.uid(),'staff_role_changed','profile',p_user_id,jsonb_build_object('from',v_old_role,'to',p_role));
end $$;

-- Existing accounts can update their own profile fields, but not their role.
drop policy if exists profiles_select_self_or_admin on public.profiles;
create policy profiles_select_self_or_admin on public.profiles
  for select to authenticated using (id=auth.uid() or public.is_frostly_admin());
drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self on public.profiles
  for update to authenticated using (id=auth.uid()) with check (id=auth.uid());

drop policy if exists products_public_read on public.products;
create policy products_public_read on public.products
  for select to anon, authenticated using (is_active or public.is_frostly_stock_manager() or public.is_frostly_catalog_manager());
drop policy if exists products_admin_write on public.products;
create policy products_admin_write on public.products
  for all to authenticated using (public.is_frostly_catalog_manager()) with check (public.is_frostly_catalog_manager());

drop policy if exists categories_public_read on public.categories;
create policy categories_public_read on public.categories
  for select to anon, authenticated using (is_active or public.is_frostly_catalog_manager() or public.is_frostly_admin());
drop policy if exists categories_admin_write on public.categories;
create policy categories_admin_write on public.categories
  for all to authenticated using (public.is_frostly_catalog_manager()) with check (public.is_frostly_catalog_manager());

drop policy if exists zones_public_read on public.delivery_zones;
create policy zones_public_read on public.delivery_zones
  for select to anon, authenticated using (is_active or public.is_frostly_delivery_manager());
drop policy if exists zones_admin_write on public.delivery_zones;
create policy zones_admin_write on public.delivery_zones
  for all to authenticated using (public.is_frostly_delivery_manager()) with check (public.is_frostly_delivery_manager());

drop policy if exists orders_customer_staff_admin_read on public.orders;
create policy orders_customer_staff_admin_read on public.orders for select to authenticated
  using (user_id=auth.uid() or public.is_frostly_order_manager() or exists(
    select 1 from public.delivery_assignments da where da.order_id=orders.id and da.staff_user_id=auth.uid()));
drop policy if exists orders_admin_update on public.orders;
create policy orders_admin_update on public.orders for update to authenticated
  using (public.is_frostly_order_manager()) with check (public.is_frostly_order_manager());
drop policy if exists order_items_related_read on public.order_items;
create policy order_items_related_read on public.order_items for select to authenticated using(
  exists(select 1 from public.orders o where o.id=order_id and
    (o.user_id=auth.uid() or public.is_frostly_order_manager() or exists(
      select 1 from public.delivery_assignments da where da.order_id=o.id and da.staff_user_id=auth.uid()))));

drop policy if exists inventory_admin_read on public.inventory_movements;
create policy inventory_admin_read on public.inventory_movements
  for select to authenticated using (public.is_frostly_stock_manager());

drop policy if exists site_settings_admin_insert on public.site_settings;
create policy site_settings_admin_insert on public.site_settings for insert to authenticated
  with check (public.is_frostly_settings_manager());
drop policy if exists site_settings_admin_update on public.site_settings;
create policy site_settings_admin_update on public.site_settings for update to authenticated
  using (public.is_frostly_settings_manager()) with check (public.is_frostly_settings_manager());

drop policy if exists frostly_site_assets_admin_insert on storage.objects;
create policy frostly_site_assets_admin_insert on storage.objects for insert to authenticated
  with check (bucket_id='frostly-site-assets' and public.is_frostly_settings_manager());
drop policy if exists frostly_site_assets_admin_update on storage.objects;
create policy frostly_site_assets_admin_update on storage.objects for update to authenticated
  using (bucket_id='frostly-site-assets' and public.is_frostly_settings_manager())
  with check (bucket_id='frostly-site-assets' and public.is_frostly_settings_manager());
drop policy if exists frostly_site_assets_admin_delete on storage.objects;
create policy frostly_site_assets_admin_delete on storage.objects for delete to authenticated
  using (bucket_id='frostly-site-assets' and public.is_frostly_settings_manager());

drop policy if exists frostly_products_admin_insert on storage.objects;
create policy frostly_products_admin_insert on storage.objects for insert to authenticated
  with check (bucket_id='frostly-products' and public.is_frostly_catalog_manager());
drop policy if exists frostly_products_admin_update on storage.objects;
create policy frostly_products_admin_update on storage.objects for update to authenticated
  using (bucket_id='frostly-products' and public.is_frostly_catalog_manager())
  with check (bucket_id='frostly-products' and public.is_frostly_catalog_manager());
drop policy if exists frostly_products_admin_delete on storage.objects;
create policy frostly_products_admin_delete on storage.objects for delete to authenticated
  using (bucket_id='frostly-products' and public.is_frostly_catalog_manager());

create or replace function public.admin_set_order_status(p_order_id uuid,p_status text,p_note text default '')
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_current text;
begin
  if not public.is_frostly_order_manager() then raise exception 'Order manager access required'; end if;
  if p_status not in ('pending_confirmation','confirmed','preparing','packed','out_for_delivery','delivered','cancelled') then raise exception 'Invalid order status'; end if;
  select status into v_current from public.orders where id=p_order_id for update;
  if not found then raise exception 'Order not found'; end if;
  if v_current=p_status then return; end if;
  if not ((v_current='pending_confirmation' and p_status in ('confirmed','cancelled')) or
          (v_current='confirmed' and p_status in ('preparing','cancelled')) or
          (v_current='preparing' and p_status in ('packed','cancelled')) or
          (v_current='packed' and p_status='out_for_delivery') or
          (v_current='out_for_delivery' and p_status in ('delivered','cancelled'))) then
    raise exception 'Order status transition is not allowed';
  end if;
  update public.orders set status=p_status,cancellation_reason=case when p_status='cancelled' then left(coalesce(p_note,''),500) else cancellation_reason end where id=p_order_id;
  if length(coalesce(p_note,''))>0 then
    update public.order_status_history set note=left(p_note,500) where order_id=p_order_id and new_status=p_status
      and created_at=(select max(created_at) from public.order_status_history where order_id=p_order_id);
  end if;
  insert into public.admin_audit_logs(actor_id,action,entity_type,entity_id,details)
  values(auth.uid(),'order_status_changed','order',p_order_id,jsonb_build_object('status',p_status));
end $$;

create or replace function public.admin_adjust_inventory(p_product_id uuid,p_new_quantity integer,p_reason text default 'Admin stock adjustment')
returns integer language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_previous integer;
begin
  if not public.is_frostly_stock_manager() then raise exception 'Stock manager access required'; end if;
  if p_new_quantity is null or p_new_quantity < 0 then raise exception 'Stock quantity must be zero or greater'; end if;
  select stock_quantity into v_previous from public.products where id=p_product_id for update;
  if not found then raise exception 'Product not found'; end if;
  if v_previous <> p_new_quantity then
    update public.products set stock_quantity=p_new_quantity,updated_at=now() where id=p_product_id;
    insert into public.inventory_movements(product_id,changed_by,quantity_delta,reason)
    values(p_product_id,auth.uid(),p_new_quantity-v_previous,coalesce(nullif(trim(p_reason),''),'Admin stock adjustment'));
  end if;
  return p_new_quantity;
end $$;

create or replace function public.admin_dashboard_metrics()
returns table(total_orders bigint,pending_orders bigint,total_sales_bdt bigint,low_stock_products bigint)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
declare v_orders boolean:=public.is_frostly_order_manager(); v_stock boolean:=public.is_frostly_stock_manager();
begin
  if not public.is_frostly_staff() then raise exception 'Staff access required'; end if;
  return query select case when v_orders then count(*) else 0 end::bigint,
    case when v_orders then count(*) filter(where status='pending_confirmation') else 0 end::bigint,
    case when v_orders then coalesce(sum(total_bdt) filter(where status<>'cancelled'),0) else 0 end::bigint,
    case when v_stock then (select count(*)::bigint from public.products where is_active and stock_quantity<=low_stock_threshold) else 0 end::bigint
  from public.orders;
end $$;

revoke all on function public.is_frostly_superadmin() from public;
revoke all on function public.is_frostly_staff() from public;
revoke all on function public.is_frostly_order_manager() from public;
revoke all on function public.is_frostly_stock_manager() from public;
revoke all on function public.is_frostly_catalog_manager() from public;
revoke all on function public.is_frostly_delivery_manager() from public;
revoke all on function public.is_frostly_settings_manager() from public;
revoke all on function public.superadmin_list_users() from public, anon;
revoke all on function public.superadmin_set_user_role(uuid,text) from public, anon;
grant execute on function public.is_frostly_superadmin() to authenticated;
grant execute on function public.is_frostly_staff() to authenticated;
grant execute on function public.is_frostly_order_manager() to authenticated;
grant execute on function public.is_frostly_stock_manager() to anon, authenticated;
grant execute on function public.is_frostly_catalog_manager() to anon, authenticated;
grant execute on function public.is_frostly_delivery_manager() to anon, authenticated;
grant execute on function public.is_frostly_settings_manager() to authenticated;
grant execute on function public.superadmin_list_users() to authenticated;
grant execute on function public.superadmin_set_user_role(uuid,text) to authenticated;
grant execute on function public.admin_set_order_status(uuid,text,text) to authenticated;
grant execute on function public.admin_adjust_inventory(uuid,integer,text) to authenticated;
grant execute on function public.admin_dashboard_metrics() to authenticated;

