-- Security tightening for deployed Frostly projects.
-- Apply after all migrations through 202610260003_custom_cake_shapes.sql.
begin;

-- PostgreSQL grants EXECUTE on new functions to PUBLIC by default. Remove
-- implicit and anonymous function access, then explicitly restore only the
-- browser RPCs that the app needs.
revoke execute on all functions in schema public from public, anon;

grant execute on function public.is_frostly_admin() to authenticated;
grant execute on function public.is_frostly_delivery() to authenticated;
grant execute on function public.is_frostly_superadmin() to authenticated;
grant execute on function public.is_frostly_staff() to authenticated;
grant execute on function public.is_frostly_order_manager() to authenticated;
grant execute on function public.is_frostly_stock_manager() to authenticated;
grant execute on function public.is_frostly_catalog_manager() to authenticated;
grant execute on function public.is_frostly_delivery_manager() to authenticated;
grant execute on function public.is_frostly_settings_manager() to authenticated;

grant execute on function public.create_cod_order(uuid,text,text,text,text,text,text,jsonb) to authenticated;
grant execute on function public.place_store_order(uuid,text,text,text,text,text,text,jsonb,text,text) to authenticated;
grant execute on function public.admin_set_order_status(uuid,text,text) to authenticated;
grant execute on function public.admin_adjust_inventory(uuid,integer,text) to authenticated;
grant execute on function public.admin_dashboard_metrics() to authenticated;
grant execute on function public.superadmin_list_users() to authenticated;
grant execute on function public.superadmin_set_user_role(uuid,text) to authenticated;
grant execute on function public.superadmin_delete_customer(uuid) to authenticated;
grant execute on function public.superadmin_delete_staff(uuid) to authenticated;
grant execute on function public.submit_cake_request(uuid,text,text,text,text,text,text,text,text) to authenticated;
grant execute on function public.newsletter_subscribe(text) to anon, authenticated;

-- Anonymous storefront reads must not execute staff-role helper functions.
-- Authenticated staff retain access to inactive catalog/delivery rows.
drop policy if exists products_public_read on public.products;
drop policy if exists products_anon_read_active on public.products;
drop policy if exists products_authenticated_read on public.products;
create policy products_anon_read_active on public.products
  for select to anon using (is_active);
create policy products_authenticated_read on public.products
  for select to authenticated
  using (is_active or public.is_frostly_stock_manager() or public.is_frostly_catalog_manager());

drop policy if exists categories_public_read on public.categories;
drop policy if exists categories_anon_read_active on public.categories;
drop policy if exists categories_authenticated_read on public.categories;
create policy categories_anon_read_active on public.categories
  for select to anon using (is_active);
create policy categories_authenticated_read on public.categories
  for select to authenticated
  using (is_active or public.is_frostly_catalog_manager() or public.is_frostly_admin());

drop policy if exists zones_public_read on public.delivery_zones;
drop policy if exists zones_anon_read_active on public.delivery_zones;
drop policy if exists zones_authenticated_read on public.delivery_zones;
create policy zones_anon_read_active on public.delivery_zones
  for select to anon using (is_active);
create policy zones_authenticated_read on public.delivery_zones
  for select to authenticated
  using (is_active or public.is_frostly_delivery_manager());

commit;
