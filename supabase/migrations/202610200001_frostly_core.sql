-- Frostly core schema. Apply in Supabase SQL Editor or with Supabase CLI.
-- Public browser access uses only the publishable/anon key and these RLS policies.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  role text not null default 'customer' check (role in ('customer','delivery','admin')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.is_frostly_admin()
returns boolean language sql stable security definer set search_path = public, pg_temp
as $$ select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin') $$;

create or replace function public.is_frostly_delivery()
returns boolean language sql stable security definer set search_path = public, pg_temp
as $$ select exists (select 1 from public.profiles where id = auth.uid() and role = 'delivery') $$;

create or replace function public.create_frostly_profile()
returns trigger language plpgsql security definer set search_path = public, pg_temp
as $$ begin
  insert into public.profiles (id, full_name) values (new.id, coalesce(new.raw_user_meta_data->>'full_name',''));
  return new;
end $$;
drop trigger if exists frostly_auth_user_profile on auth.users;
create trigger frostly_auth_user_profile after insert on auth.users for each row execute function public.create_frostly_profile();

create or replace function public.prevent_profile_role_change()
returns trigger language plpgsql security definer set search_path = public, pg_temp
as $$ begin
  if new.role is distinct from old.role and not public.is_frostly_admin() then
    raise exception 'Profile roles can only be changed by an administrator';
  end if;
  new.updated_at := now();
  return new;
end $$;
drop trigger if exists protect_frostly_profile_role on public.profiles;
create trigger protect_frostly_profile_role before update on public.profiles for each row execute function public.prevent_profile_role_change();

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name_en text not null,
  name_bn text not null,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  category_id uuid references public.categories(id) on delete set null,
  slug text not null unique,
  sku text not null unique,
  name_en text not null,
  name_bn text not null,
  description_en text not null default '',
  description_bn text not null default '',
  package_size_en text not null default '',
  package_size_bn text not null default '',
  price_bdt integer not null check (price_bdt >= 0),
  compare_at_bdt integer check (compare_at_bdt is null or compare_at_bdt >= price_bdt),
  image_url text not null default '',
  stock_quantity integer not null default 0 check (stock_quantity >= 0),
  low_stock_threshold integer not null default 5 check (low_stock_threshold >= 0),
  is_active boolean not null default false,
  is_featured boolean not null default false,
  is_demo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists products_public_listing_idx on public.products(is_active, is_featured, category_id);

create table if not exists public.delivery_zones (
  id uuid primary key default gen_random_uuid(),
  area_name text not null unique,
  delivery_fee_bdt integer not null check (delivery_fee_bdt >= 0),
  is_active boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.addresses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  recipient_name text not null,
  phone text not null,
  address text not null,
  area_name text not null,
  instructions text not null default '',
  created_at timestamptz not null default now()
);
create index if not exists addresses_user_idx on public.addresses(user_id, created_at desc);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id),
  request_id uuid not null,
  order_number bigint generated always as identity unique,
  customer_name text not null,
  customer_phone text not null,
  delivery_address text not null,
  delivery_area text not null,
  delivery_instructions text not null default '',
  order_notes text not null default '',
  status text not null default 'pending_confirmation' check (status in ('pending_confirmation','confirmed','preparing','packed','out_for_delivery','delivered','cancelled')),
  payment_method text not null default 'cod' check (payment_method = 'cod'),
  payment_status text not null default 'due' check (payment_status in ('due','collected','refunded')),
  subtotal_bdt integer not null check (subtotal_bdt >= 0),
  delivery_fee_bdt integer not null check (delivery_fee_bdt >= 0),
  total_bdt integer not null check (total_bdt = subtotal_bdt + delivery_fee_bdt),
  cancellation_reason text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id, request_id)
);
create index if not exists orders_user_created_idx on public.orders(user_id, created_at desc);
create index if not exists orders_status_created_idx on public.orders(status, created_at desc);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  product_name_en text not null,
  product_name_bn text not null,
  sku text not null,
  package_size_en text not null,
  package_size_bn text not null,
  unit_price_bdt integer not null check (unit_price_bdt >= 0),
  quantity integer not null check (quantity between 1 and 50),
  line_total_bdt integer not null check (line_total_bdt = unit_price_bdt * quantity)
);
create index if not exists order_items_order_idx on public.order_items(order_id);

create table if not exists public.delivery_staff_profiles (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);
create table if not exists public.delivery_assignments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  staff_user_id uuid not null references public.delivery_staff_profiles(user_id),
  assigned_by uuid not null references public.profiles(id),
  assigned_at timestamptz not null default now(),
  unique(order_id)
);
create index if not exists delivery_assignments_staff_idx on public.delivery_assignments(staff_user_id, assigned_at desc);

create table if not exists public.inventory_movements (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id),
  changed_by uuid references public.profiles(id),
  quantity_delta integer not null check (quantity_delta <> 0),
  reason text not null,
  created_at timestamptz not null default now()
);
create table if not exists public.order_status_history (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  changed_by uuid references public.profiles(id),
  old_status text,
  new_status text not null,
  note text not null default '',
  created_at timestamptz not null default now()
);
create table if not exists public.admin_audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.profiles(id),
  action text not null,
  entity_type text not null,
  entity_id uuid,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create table if not exists public.newsletter_subscriptions (
  id uuid primary key default gen_random_uuid(),
  email text not null unique,
  consented_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create or replace function public.log_order_status_change()
returns trigger language plpgsql security definer set search_path = public, pg_temp
as $$ begin
  if new.status is distinct from old.status then
    new.updated_at := now();
    insert into public.order_status_history(order_id, changed_by, old_status, new_status)
    values(new.id, auth.uid(), old.status, new.status);
  end if;
  return new;
end $$;
drop trigger if exists order_status_history_trigger on public.orders;
create trigger order_status_history_trigger before update on public.orders for each row execute function public.log_order_status_change();

-- Atomic, idempotent COD order placement. Prices, delivery fees, stock and totals are read server-side.
create or replace function public.create_cod_order(
  p_request_id uuid,
  p_customer_name text,
  p_customer_phone text,
  p_delivery_address text,
  p_delivery_area text,
  p_delivery_instructions text,
  p_order_notes text,
  p_items jsonb
) returns uuid language plpgsql security definer set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_existing uuid;
  v_zone_fee integer;
  v_subtotal integer := 0;
  v_order_id uuid;
  v_item jsonb;
  v_product public.products%rowtype;
  v_qty integer;
begin
  if v_user is null then raise exception 'Sign in is required to place an order'; end if;
  if p_request_id is null then raise exception 'An idempotency request ID is required'; end if;
  perform pg_advisory_xact_lock(hashtextextended(v_user::text || p_request_id::text, 0));
  select id into v_existing from public.orders where user_id = v_user and request_id = p_request_id;
  if v_existing is not null then return v_existing; end if;
  if length(trim(coalesce(p_customer_name,''))) not between 2 and 120 then raise exception 'Enter a valid customer name'; end if;
  if trim(coalesce(p_customer_phone,'')) !~ '^(\+?88)?01[3-9][0-9]{8}$' then raise exception 'Enter a valid Bangladesh phone number'; end if;
  if length(trim(coalesce(p_delivery_address,''))) < 8 then raise exception 'Enter a complete delivery address'; end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) not between 1 and 30 then raise exception 'The cart is empty or invalid'; end if;
  if (select count(*) from jsonb_array_elements(p_items)) <> (select count(distinct value->>'product_id') from jsonb_array_elements(p_items)) then raise exception 'Duplicate cart products are not allowed'; end if;
  select delivery_fee_bdt into v_zone_fee from public.delivery_zones where is_active and lower(area_name)=lower(trim(p_delivery_area));
  if v_zone_fee is null then raise exception 'Delivery is not configured for this area yet'; end if;
  for v_item in select value from jsonb_array_elements(p_items) loop
    v_qty := (v_item->>'quantity')::integer;
    if v_qty is null or v_qty not between 1 and 50 then raise exception 'Invalid product quantity'; end if;
    select * into v_product from public.products where id=(v_item->>'product_id')::uuid and is_active for update;
    if not found then raise exception 'A product in your cart is unavailable'; end if;
    if v_product.stock_quantity < v_qty then raise exception 'Insufficient stock for %', v_product.name_en; end if;
    v_subtotal := v_subtotal + v_product.price_bdt * v_qty;
  end loop;
  insert into public.orders(user_id,request_id,customer_name,customer_phone,delivery_address,delivery_area,delivery_instructions,order_notes,subtotal_bdt,delivery_fee_bdt,total_bdt)
  values(v_user,p_request_id,trim(p_customer_name),trim(p_customer_phone),trim(p_delivery_address),trim(p_delivery_area),coalesce(p_delivery_instructions,''),coalesce(p_order_notes,''),v_subtotal,v_zone_fee,v_subtotal+v_zone_fee)
  on conflict(user_id,request_id) do nothing returning id into v_order_id;
  if v_order_id is null then
    select id into v_order_id from public.orders where user_id=v_user and request_id=p_request_id;
    return v_order_id;
  end if;
  for v_item in select value from jsonb_array_elements(p_items) loop
    v_qty := (v_item->>'quantity')::integer;
    select * into v_product from public.products where id=(v_item->>'product_id')::uuid for update;
    update public.products set stock_quantity=stock_quantity-v_qty, updated_at=now() where id=v_product.id;
    insert into public.order_items(order_id,product_id,product_name_en,product_name_bn,sku,package_size_en,package_size_bn,unit_price_bdt,quantity,line_total_bdt)
    values(v_order_id,v_product.id,v_product.name_en,v_product.name_bn,v_product.sku,v_product.package_size_en,v_product.package_size_bn,v_product.price_bdt,v_qty,v_product.price_bdt*v_qty);
    insert into public.inventory_movements(product_id,changed_by,quantity_delta,reason)
    values(v_product.id,v_user,-v_qty,'COD order '||v_order_id::text);
  end loop;
  insert into public.order_status_history(order_id,changed_by,old_status,new_status,note)
  values(v_order_id,v_user,null,'pending_confirmation','COD order created');
  return v_order_id;
end $$;

create or replace function public.admin_set_order_status(p_order_id uuid,p_status text,p_note text default '')
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_role text; v_current text;
begin
  select role into v_role from public.profiles where id=auth.uid();
  if v_role is distinct from 'admin' then raise exception 'Administrator access required'; end if;
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
  update public.orders set status=p_status, cancellation_reason=case when p_status='cancelled' then left(coalesce(p_note,''),500) else cancellation_reason end where id=p_order_id;
  if length(coalesce(p_note,''))>0 then
    update public.order_status_history set note=left(p_note,500) where order_id=p_order_id and new_status=p_status and created_at=(select max(created_at) from public.order_status_history where order_id=p_order_id);
  end if;
  insert into public.admin_audit_logs(actor_id,action,entity_type,entity_id,details)
  values(auth.uid(),'order_status_changed','order',p_order_id,jsonb_build_object('status',p_status));
end $$;

create or replace function public.admin_dashboard_metrics()
returns table(total_orders bigint,pending_orders bigint,total_sales_bdt bigint,low_stock_products bigint)
language plpgsql stable security definer set search_path = public, pg_temp
as $$ begin
  if not public.is_frostly_admin() then raise exception 'Administrator access required'; end if;
  return query
    select count(*)::bigint,
           count(*) filter(where status='pending_confirmation')::bigint,
           coalesce(sum(total_bdt) filter(where status<>'cancelled'),0)::bigint,
           (select count(*)::bigint from public.products where is_active and stock_quantity<=low_stock_threshold)
    from public.orders;
end $$;

alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.delivery_zones enable row level security;
alter table public.addresses enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.delivery_staff_profiles enable row level security;
alter table public.delivery_assignments enable row level security;
alter table public.inventory_movements enable row level security;
alter table public.order_status_history enable row level security;
alter table public.admin_audit_logs enable row level security;
alter table public.newsletter_subscriptions enable row level security;

drop policy if exists profiles_select_self_or_admin on public.profiles;
create policy profiles_select_self_or_admin on public.profiles for select to authenticated using (id=auth.uid() or public.is_frostly_admin());
drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self on public.profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid());
drop policy if exists categories_public_read on public.categories;
create policy categories_public_read on public.categories for select to anon, authenticated using(is_active or public.is_frostly_admin());
drop policy if exists products_public_read on public.products;
create policy products_public_read on public.products for select to anon, authenticated using(is_active or public.is_frostly_admin());
drop policy if exists products_admin_write on public.products;
create policy products_admin_write on public.products for all to authenticated using(public.is_frostly_admin()) with check(public.is_frostly_admin());
drop policy if exists categories_admin_write on public.categories;
create policy categories_admin_write on public.categories for all to authenticated using(public.is_frostly_admin()) with check(public.is_frostly_admin());
drop policy if exists zones_public_read on public.delivery_zones;
create policy zones_public_read on public.delivery_zones for select to anon, authenticated using(is_active or public.is_frostly_admin());
drop policy if exists zones_admin_write on public.delivery_zones;
create policy zones_admin_write on public.delivery_zones for all to authenticated using(public.is_frostly_admin()) with check(public.is_frostly_admin());
drop policy if exists addresses_owner_access on public.addresses;
create policy addresses_owner_access on public.addresses for all to authenticated using(user_id=auth.uid() or public.is_frostly_admin()) with check(user_id=auth.uid() or public.is_frostly_admin());
drop policy if exists orders_customer_staff_admin_read on public.orders;
create policy orders_customer_staff_admin_read on public.orders for select to authenticated using(user_id=auth.uid() or public.is_frostly_admin() or exists(select 1 from public.delivery_assignments da where da.order_id=orders.id and da.staff_user_id=auth.uid()));
drop policy if exists orders_admin_update on public.orders;
create policy orders_admin_update on public.orders for update to authenticated using(public.is_frostly_admin()) with check(public.is_frostly_admin());
drop policy if exists order_items_related_read on public.order_items;
create policy order_items_related_read on public.order_items for select to authenticated using(exists(select 1 from public.orders o where o.id=order_id and (o.user_id=auth.uid() or public.is_frostly_admin() or exists(select 1 from public.delivery_assignments da where da.order_id=o.id and da.staff_user_id=auth.uid()))));
drop policy if exists delivery_staff_self_admin_read on public.delivery_staff_profiles;
create policy delivery_staff_self_admin_read on public.delivery_staff_profiles for select to authenticated using(user_id=auth.uid() or public.is_frostly_admin());
drop policy if exists delivery_staff_admin_write on public.delivery_staff_profiles;
create policy delivery_staff_admin_write on public.delivery_staff_profiles for all to authenticated using(public.is_frostly_admin()) with check(public.is_frostly_admin());
drop policy if exists assignments_related_read on public.delivery_assignments;
create policy assignments_related_read on public.delivery_assignments for select to authenticated using(staff_user_id=auth.uid() or public.is_frostly_admin());
drop policy if exists assignments_admin_write on public.delivery_assignments;
create policy assignments_admin_write on public.delivery_assignments for all to authenticated using(public.is_frostly_admin()) with check(public.is_frostly_admin());
drop policy if exists inventory_admin_read on public.inventory_movements;
create policy inventory_admin_read on public.inventory_movements for select to authenticated using(public.is_frostly_admin());
drop policy if exists history_related_read on public.order_status_history;
create policy history_related_read on public.order_status_history for select to authenticated using(exists(select 1 from public.orders o where o.id=order_id and (o.user_id=auth.uid() or public.is_frostly_admin() or exists(select 1 from public.delivery_assignments da where da.order_id=o.id and da.staff_user_id=auth.uid()))));
drop policy if exists admin_logs_admin_read on public.admin_audit_logs;
create policy admin_logs_admin_read on public.admin_audit_logs for select to authenticated using(public.is_frostly_admin());
drop policy if exists newsletter_insert_public on public.newsletter_subscriptions;
create policy newsletter_insert_public on public.newsletter_subscriptions for insert to anon, authenticated with check (email ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$');

revoke all on public.profiles,public.categories,public.products,public.delivery_zones,public.addresses,public.orders,public.order_items,public.delivery_staff_profiles,public.delivery_assignments,public.inventory_movements,public.order_status_history,public.admin_audit_logs,public.newsletter_subscriptions from anon,authenticated;
grant select on public.categories,public.products,public.delivery_zones to anon,authenticated;
grant select,update on public.profiles to authenticated;
grant select,insert,update,delete on public.addresses to authenticated;
grant select on public.orders,public.order_items,public.delivery_assignments,public.delivery_staff_profiles,public.order_status_history to authenticated;
grant select,insert on public.newsletter_subscriptions to anon,authenticated;
grant select,insert,update on public.products,public.categories,public.delivery_zones,public.delivery_staff_profiles,public.delivery_assignments to authenticated;
grant select on public.inventory_movements,public.admin_audit_logs to authenticated;
revoke all on function public.is_frostly_admin() from public;
revoke all on function public.is_frostly_delivery() from public;
revoke all on function public.create_frostly_profile() from public,anon,authenticated;
revoke all on function public.prevent_profile_role_change() from public,anon,authenticated;
revoke all on function public.log_order_status_change() from public,anon,authenticated;
revoke all on function public.create_cod_order(uuid,text,text,text,text,text,text,jsonb) from public,anon;
revoke all on function public.admin_set_order_status(uuid,text,text) from public,anon;
revoke all on function public.admin_dashboard_metrics() from public,anon;
grant execute on function public.is_frostly_admin() to anon,authenticated;
grant execute on function public.is_frostly_delivery() to authenticated;
grant execute on function public.create_cod_order(uuid,text,text,text,text,text,text,jsonb) to authenticated;
grant execute on function public.admin_set_order_status(uuid,text,text) to authenticated;
grant execute on function public.admin_dashboard_metrics() to authenticated;
grant execute on function public.is_frostly_admin() to authenticated;

-- Demonstration-only catalog rows. Configure real prices, inventory, and delivery zones before taking orders.
insert into public.categories(id,slug,name_en,name_bn,sort_order) values
('b1000000-0000-4000-8000-000000000001','chicken-meat','Chicken & Meat','মুরগি ও মাংস',1),
('b1000000-0000-4000-8000-000000000002','fish-seafood','Fish & Seafood','মাছ ও সামুদ্রিক',2),
('b1000000-0000-4000-8000-000000000003','vegetables','Vegetables','সবজি',3),
('b1000000-0000-4000-8000-000000000004','paratha-roti','Paratha & Roti','পরোটা ও রুটি',4),
('b1000000-0000-4000-8000-000000000005','samosa-snacks','Samosa & Snacks','সামোসা ও স্ন্যাকস',5),
('b1000000-0000-4000-8000-000000000006','nuggets-fries','Nuggets & Fries','নাগেটস ও ফ্রাই',6)
on conflict(slug) do nothing;
insert into public.products(id,category_id,slug,sku,name_en,name_bn,description_en,description_bn,package_size_en,package_size_bn,price_bdt,stock_quantity,is_active,is_featured,is_demo,image_url) values
('a1000000-0000-4000-8000-000000000001','b1000000-0000-4000-8000-000000000001','boneless-chicken','FST-DEM-001','Boneless Chicken','বোনলেস চিকেন','Demo catalog item. Replace with verified product details.','নমুনা পণ্য। যাচাইকৃত তথ্য দিয়ে পরিবর্তন করুন।','500 g','৫০০ গ্রাম',220,25,true,true,true,'https://images.unsplash.com/photo-1604503468506-a8da13d82791?auto=format&fit=crop&w=600&q=80'),
('a1000000-0000-4000-8000-000000000002','b1000000-0000-4000-8000-000000000002','rohu-fish-cut','FST-DEM-002','Rohu Fish (Cut)','রুই মাছ (কাটা)','Demo catalog item. Replace with verified product details.','নমুনা পণ্য। যাচাইকৃত তথ্য দিয়ে পরিবর্তন করুন।','1 kg','১ কেজি',420,25,true,true,true,'https://images.unsplash.com/photo-1510130387422-82bed34b37e9?auto=format&fit=crop&w=600&q=80'),
('a1000000-0000-4000-8000-000000000003','b1000000-0000-4000-8000-000000000003','mixed-vegetables','FST-DEM-003','Mixed Vegetables','মিক্সড ভেজিটেবল','Demo catalog item. Replace with verified product details.','নমুনা পণ্য। যাচাইকৃত তথ্য দিয়ে পরিবর্তন করুন।','1 kg','১ কেজি',180,25,true,true,true,'https://images.unsplash.com/photo-1597362925123-77861d3fbac7?auto=format&fit=crop&w=600&q=80'),
('a1000000-0000-4000-8000-000000000004','b1000000-0000-4000-8000-000000000004','frozen-paratha','FST-DEM-004','Frozen Paratha','পরোটা (ফ্রোজেন)','Demo catalog item. Replace with verified product details.','নমুনা পণ্য। যাচাইকৃত তথ্য দিয়ে পরিবর্তন করুন।','10 pcs','১০ পিস',150,25,true,true,true,'https://images.unsplash.com/photo-1601050690597-df0568f70950?auto=format&fit=crop&w=600&q=80'),
('a1000000-0000-4000-8000-000000000005','b1000000-0000-4000-8000-000000000005','vegetable-samosa','FST-DEM-005','Vegetable Samosa','ভেজিটেবল সামোসা','Demo catalog item. Replace with verified product details.','নমুনা পণ্য। যাচাইকৃত তথ্য দিয়ে পরিবর্তন করুন।','12 pcs','১২ পিস',190,25,true,true,true,'https://images.unsplash.com/photo-1601050690117-94f5f6fa8bd7?auto=format&fit=crop&w=600&q=80'),
('a1000000-0000-4000-8000-000000000006','b1000000-0000-4000-8000-000000000006','chicken-nuggets','FST-DEM-006','Chicken Nuggets','চিকেন নাগেটস','Demo catalog item. Replace with verified product details.','নমুনা পণ্য। যাচাইকৃত তথ্য দিয়ে পরিবর্তন করুন।','500 g','৫০০ গ্রাম',260,25,true,true,true,'https://images.unsplash.com/photo-1562967914-608f82629710?auto=format&fit=crop&w=600&q=80'),
('a1000000-0000-4000-8000-000000000007','b1000000-0000-4000-8000-000000000002','fish-fillet','FST-DEM-007','Fish Fillet','ফিশ ফিলেট','Demo catalog item. Replace with verified product details.','নমুনা পণ্য। যাচাইকৃত তথ্য দিয়ে পরিবর্তন করুন।','500 g','৫০০ গ্রাম',350,25,true,false,true,'https://images.unsplash.com/photo-1510130387422-82bed34b37e9?auto=format&fit=crop&w=600&q=80'),
('a1000000-0000-4000-8000-000000000008','b1000000-0000-4000-8000-000000000001','chicken-kebab','FST-DEM-008','Chicken Kebab','চিকেন কাবাব','Demo catalog item. Replace with verified product details.','নমুনা পণ্য। যাচাইকৃত তথ্য দিয়ে পরিবর্তন করুন।','400 g','৪০০ গ্রাম',280,25,true,false,true,'https://images.unsplash.com/photo-1607623814075-e51df1bdc82f?auto=format&fit=crop&w=600&q=80')
on conflict(id) do nothing;
