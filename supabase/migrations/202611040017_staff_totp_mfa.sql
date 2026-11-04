-- Require a verified Supabase Authenticator (TOTP) factor for every staff
-- permission helper. Staff remain able to read their own profile at AAL1 so
-- the admin app can identify their role and guide first-time enrollment.
-- Deploy the app with the MFA enrollment UI before applying this migration.

create or replace function public.is_frostly_superadmin()
returns boolean language sql stable security definer set search_path = public, pg_temp
as $$
  select coalesce(auth.jwt()->>'aal', 'aal1') = 'aal2'
     and exists (select 1 from public.profiles where id=auth.uid() and role='superadmin')
$$;

create or replace function public.is_frostly_admin()
returns boolean language sql stable security definer set search_path = public, pg_temp
as $$
  select coalesce(auth.jwt()->>'aal', 'aal1') = 'aal2'
     and exists (select 1 from public.profiles where id=auth.uid() and role in ('superadmin','admin'))
$$;

create or replace function public.is_frostly_staff()
returns boolean language sql stable security definer set search_path = public, pg_temp
as $$
  select coalesce(auth.jwt()->>'aal', 'aal1') = 'aal2'
     and exists (select 1 from public.profiles where id=auth.uid() and role in ('superadmin','admin','ordermanager','stockmanager','catalogmanager','deliverymanager','settingsmanager'))
$$;

create or replace function public.is_frostly_order_manager()
returns boolean language sql stable security definer set search_path = public, pg_temp
as $$
  select coalesce(auth.jwt()->>'aal', 'aal1') = 'aal2'
     and exists (select 1 from public.profiles where id=auth.uid() and role in ('superadmin','admin','ordermanager'))
$$;

create or replace function public.is_frostly_stock_manager()
returns boolean language sql stable security definer set search_path = public, pg_temp
as $$
  select coalesce(auth.jwt()->>'aal', 'aal1') = 'aal2'
     and exists (select 1 from public.profiles where id=auth.uid() and role in ('superadmin','admin','stockmanager'))
$$;

create or replace function public.is_frostly_catalog_manager()
returns boolean language sql stable security definer set search_path = public, pg_temp
as $$
  select coalesce(auth.jwt()->>'aal', 'aal1') = 'aal2'
     and exists (select 1 from public.profiles where id=auth.uid() and role in ('superadmin','admin','catalogmanager'))
$$;

create or replace function public.is_frostly_delivery_manager()
returns boolean language sql stable security definer set search_path = public, pg_temp
as $$
  select coalesce(auth.jwt()->>'aal', 'aal1') = 'aal2'
     and exists (select 1 from public.profiles where id=auth.uid() and role in ('superadmin','admin','deliverymanager'))
$$;

create or replace function public.is_frostly_settings_manager()
returns boolean language sql stable security definer set search_path = public, pg_temp
as $$
  select coalesce(auth.jwt()->>'aal', 'aal1') = 'aal2'
     and exists (select 1 from public.profiles where id=auth.uid() and role in ('superadmin','admin','settingsmanager'))
$$;

create or replace function public.is_frostly_delivery()
returns boolean language sql stable security definer set search_path = public, pg_temp
as $$
  select coalesce(auth.jwt()->>'aal', 'aal1') = 'aal2'
     and exists (select 1 from public.profiles where id=auth.uid() and role='delivery')
$$;

revoke all on function public.is_frostly_superadmin() from public, anon;
revoke all on function public.is_frostly_admin() from public, anon;
revoke all on function public.is_frostly_staff() from public, anon;
revoke all on function public.is_frostly_order_manager() from public, anon;
revoke all on function public.is_frostly_stock_manager() from public, anon;
revoke all on function public.is_frostly_catalog_manager() from public, anon;
revoke all on function public.is_frostly_delivery_manager() from public, anon;
revoke all on function public.is_frostly_settings_manager() from public, anon;
revoke all on function public.is_frostly_delivery() from public, anon;

grant execute on function public.is_frostly_superadmin() to authenticated;
grant execute on function public.is_frostly_admin() to authenticated;
grant execute on function public.is_frostly_staff() to authenticated;
grant execute on function public.is_frostly_order_manager() to authenticated;
grant execute on function public.is_frostly_stock_manager() to authenticated;
grant execute on function public.is_frostly_catalog_manager() to authenticated;
grant execute on function public.is_frostly_delivery_manager() to authenticated;
grant execute on function public.is_frostly_settings_manager() to authenticated;
grant execute on function public.is_frostly_delivery() to authenticated;
