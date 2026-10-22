-- Configurable manual mobile-wallet payment instructions and secure order capture.
-- This records a customer's transaction reference; it does not verify wallet transfers.

alter table public.site_settings
  add column if not exists accept_cod boolean not null default true,
  add column if not exists accept_bkash boolean not null default true,
  add column if not exists bkash_number text not null default '01811111111',
  add column if not exists accept_nagad boolean not null default true,
  add column if not exists nagad_number text not null default '01811111111',
  add column if not exists accept_rocket boolean not null default true,
  add column if not exists rocket_number text not null default '01811111111';

alter table public.orders
  add column if not exists payment_reference text not null default '';
alter table public.orders drop constraint if exists orders_payment_method_check;
alter table public.orders add constraint orders_payment_method_check
  check (payment_method in ('cod','bkash','nagad','rocket'));
alter table public.orders drop constraint if exists orders_payment_status_check;
alter table public.orders add constraint orders_payment_status_check
  check (payment_status in ('due','pending_verification','collected','refunded'));

create or replace function public.place_store_order(
  p_request_id uuid,
  p_customer_name text,
  p_customer_phone text,
  p_delivery_address text,
  p_delivery_area text,
  p_delivery_instructions text,
  p_order_notes text,
  p_items jsonb,
  p_payment_method text,
  p_payment_reference text
) returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_existing uuid;
  v_existing_method text;
  v_existing_reference text;
  v_zone_fee integer;
  v_subtotal integer := 0;
  v_order_id uuid;
  v_item jsonb;
  v_product public.products%rowtype;
  v_qty integer;
  v_method text := lower(trim(coalesce(p_payment_method,'')));
  v_reference text := trim(coalesce(p_payment_reference,''));
  v_enabled boolean := false;
  v_pay_to text := '';
begin
  if v_user is null then raise exception 'Sign in is required to place an order'; end if;
  if p_request_id is null then raise exception 'An idempotency request ID is required'; end if;
  if v_method not in ('cod','bkash','nagad','rocket') then raise exception 'Choose an available payment method'; end if;
  perform pg_advisory_xact_lock(hashtextextended(v_user::text || p_request_id::text, 0));
  select id,payment_method,payment_reference
    into v_existing,v_existing_method,v_existing_reference
    from public.orders where user_id=v_user and request_id=p_request_id;
  if v_existing is not null then
    if v_existing_method is distinct from v_method or v_existing_reference is distinct from v_reference then
      raise exception 'This request ID was already used for another payment choice';
    end if;
    return v_existing;
  end if;

  if v_method='cod' then
    select coalesce(accept_cod,true) into v_enabled from public.site_settings where id='main';
    v_enabled := coalesce(v_enabled,true);
  elsif v_method='bkash' then
    select accept_bkash,bkash_number into v_enabled,v_pay_to from public.site_settings where id='main';
  elsif v_method='nagad' then
    select accept_nagad,nagad_number into v_enabled,v_pay_to from public.site_settings where id='main';
  else
    select accept_rocket,rocket_number into v_enabled,v_pay_to from public.site_settings where id='main';
  end if;
  if not coalesce(v_enabled,false) then raise exception 'This payment method is not currently available'; end if;
  if v_method<>'cod' then
    if coalesce(v_pay_to,'') !~ '^(\+?88)?01[3-9][0-9]{8}$' then raise exception 'The receiving wallet number is not configured correctly'; end if;
    if length(v_reference) not between 4 and 80 or v_reference !~ '^[A-Za-z0-9_-]+$' then
      raise exception 'Enter a valid transaction ID after sending the payment';
    end if;
  elsif v_reference<>'' then
    raise exception 'A transaction ID is only used for mobile-wallet payments';
  end if;

  if length(trim(coalesce(p_customer_name,''))) not between 2 and 120 then raise exception 'Enter a valid customer name'; end if;
  if trim(coalesce(p_customer_phone,'')) !~ '^(\+?88)?01[3-9][0-9]{8}$' then raise exception 'Enter a valid Bangladesh phone number'; end if;
  if length(trim(coalesce(p_delivery_address,''))) < 8 then raise exception 'Enter a complete delivery address'; end if;
  if p_items is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items) not between 1 and 30 then raise exception 'The cart is empty or invalid'; end if;
  if (select count(*) from jsonb_array_elements(p_items))<>(select count(distinct value->>'product_id') from jsonb_array_elements(p_items)) then raise exception 'Duplicate cart products are not allowed'; end if;
  select delivery_fee_bdt into v_zone_fee from public.delivery_zones where is_active and lower(area_name)=lower(trim(p_delivery_area));
  if v_zone_fee is null then raise exception 'Delivery is not configured for this area yet'; end if;

  for v_item in select value from jsonb_array_elements(p_items) loop
    v_qty := (v_item->>'quantity')::integer;
    if v_qty is null or v_qty not between 1 and 50 then raise exception 'Invalid product quantity'; end if;
    select * into v_product from public.products where id=(v_item->>'product_id')::uuid and is_active for update;
    if not found then raise exception 'A product in your cart is unavailable'; end if;
    if v_product.stock_quantity<v_qty then raise exception 'Insufficient stock for %',v_product.name_en; end if;
    v_subtotal := v_subtotal+v_product.price_bdt*v_qty;
  end loop;

  insert into public.orders(user_id,request_id,customer_name,customer_phone,delivery_address,delivery_area,delivery_instructions,order_notes,payment_method,payment_reference,payment_status,subtotal_bdt,delivery_fee_bdt,total_bdt)
  values(v_user,p_request_id,trim(p_customer_name),trim(p_customer_phone),trim(p_delivery_address),trim(p_delivery_area),coalesce(p_delivery_instructions,''),coalesce(p_order_notes,''),v_method,v_reference,case when v_method='cod' then 'due' else 'pending_verification' end,v_subtotal,v_zone_fee,v_subtotal+v_zone_fee)
  on conflict(user_id,request_id) do nothing returning id into v_order_id;
  if v_order_id is null then
    select id into v_order_id from public.orders where user_id=v_user and request_id=p_request_id;
    return v_order_id;
  end if;
  for v_item in select value from jsonb_array_elements(p_items) loop
    v_qty := (v_item->>'quantity')::integer;
    select * into v_product from public.products where id=(v_item->>'product_id')::uuid for update;
    update public.products set stock_quantity=stock_quantity-v_qty,updated_at=now() where id=v_product.id;
    insert into public.order_items(order_id,product_id,product_name_en,product_name_bn,sku,package_size_en,package_size_bn,unit_price_bdt,quantity,line_total_bdt)
    values(v_order_id,v_product.id,v_product.name_en,v_product.name_bn,v_product.sku,v_product.package_size_en,v_product.package_size_bn,v_product.price_bdt,v_qty,v_product.price_bdt*v_qty);
    insert into public.inventory_movements(product_id,changed_by,quantity_delta,reason)
    values(v_product.id,v_user,-v_qty,'Order '||v_order_id::text);
  end loop;
  insert into public.order_status_history(order_id,changed_by,old_status,new_status,note)
  values(v_order_id,v_user,null,'pending_confirmation',case when v_method='cod' then 'COD order created' else 'Mobile-wallet payment submitted for manual verification' end);
  return v_order_id;
end;
$$;

-- Keep the legacy COD endpoint, but route it through the same setting and pricing checks.
create or replace function public.create_cod_order(
  p_request_id uuid,
  p_customer_name text,
  p_customer_phone text,
  p_delivery_address text,
  p_delivery_area text,
  p_delivery_instructions text,
  p_order_notes text,
  p_items jsonb
) returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  return public.place_store_order(p_request_id,p_customer_name,p_customer_phone,p_delivery_address,p_delivery_area,p_delivery_instructions,p_order_notes,p_items,'cod','');
end;
$$;

revoke all on function public.place_store_order(uuid,text,text,text,text,text,text,jsonb,text,text) from public,anon;
grant execute on function public.place_store_order(uuid,text,text,text,text,text,text,jsonb,text,text) to authenticated;
revoke all on function public.create_cod_order(uuid,text,text,text,text,text,text,jsonb) from public,anon;
grant execute on function public.create_cod_order(uuid,text,text,text,text,text,text,jsonb) to authenticated;
