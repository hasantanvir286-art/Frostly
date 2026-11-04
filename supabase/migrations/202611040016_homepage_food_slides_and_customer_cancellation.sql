-- Store the refreshed homepage carousel in Supabase. Replace only the original
-- built-in slides or an empty list; preserve any slides customized in Admin.
insert into public.site_settings as current_settings (id, site_name, logo_url, hero_slides)
values (
  'main',
  'Nawrah Kitchen',
  '/nawrah-emblem-champagne-ice.png?v=20261102-champagne-ice',
  '[
    {"image_url":"https://images.unsplash.com/photo-1547592180-85f173990554?auto=format&fit=crop&w=1400&q=82","title_en":"Dinner is ready when you are.","title_bn":"রাতের খাবার প্রস্তুত, যখনই আপনি চান।","copy_en":"Hygienically packed favourites, delivered across Chattogram.","copy_bn":"স্বাস্থ্যসম্মতভাবে প্যাক করা খাবার চট্টগ্রামজুড়ে পৌঁছে যায়।"},
    {"image_url":"https://images.unsplash.com/photo-1601050690117-94f5f6fa8bd7?auto=format&fit=crop&w=1400&q=82","title_en":"Fresh frozen samosas, ready when you are.","title_bn":"ফ্রেশ ফ্রোজেন সামোসা, যখনই চান প্রস্তুত।","copy_en":"A family favourite, hygienically packed and kept frozen.","copy_bn":"পরিবারের পছন্দের সামোসা, স্বাস্থ্যসম্মতভাবে প্যাক করে ফ্রোজেন রাখা হয়।"},
    {"image_url":"https://images.unsplash.com/photo-1562967914-608f82629710?auto=format&fit=crop&w=1400&q=82","title_en":"Chicken nuggets for easy meals.","title_bn":"সহজ খাবারের জন্য চিকেন নাগেটস।","copy_en":"Quick to prepare, carefully packed and delivered across Chattogram.","copy_bn":"সহজে তৈরি করুন—যত্নে প্যাক করে চট্টগ্রামজুড়ে পৌঁছে দিই।"},
    {"image_url":"https://images.unsplash.com/photo-1695712641388-87c0f9c2d36e?auto=format&fit=crop&w=1400&q=82","title_en":"Golden rolls, frozen fresh for later.","title_bn":"গোল্ডেন রোল, পরে উপভোগের জন্য ফ্রোজেন।","copy_en":"Keep a delicious snack ready in your freezer.","copy_bn":"ফ্রিজারে রাখুন, পছন্দের নাশতা থাকবে হাতের কাছে।"}
  ]'::jsonb
)
on conflict (id) do update
set hero_slides = excluded.hero_slides,
    updated_at = now()
where current_settings.hero_slides = '[]'::jsonb
   or current_settings.hero_slides = '[
     {"image_url":"https://images.unsplash.com/photo-1510130387422-82bed34b37e9?auto=format&fit=crop&w=1200&q=85","title_en":"Premium Frozen Food Now in Chattogram","title_bn":"প্রিমিয়াম ফ্রোজেন খাবার এখন চট্টগ্রামে","copy_en":"Safe, delicious, quality frozen food for your family.","copy_bn":"আপনার পরিবারের জন্য নিরাপদ, সুস্বাদু ও মানসম্মত ফ্রোজেন খাবার।"},
     {"image_url":"https://images.unsplash.com/photo-1604503468506-a8da13d82791?auto=format&fit=crop&w=1200&q=85","title_en":"Delicious favourites, delivered frozen fresh","title_bn":"পরিবারের পছন্দের খাবার, ফ্রোজেন সতেজতায় পৌঁছে যাবে","copy_en":"Choose from family favourites, carefully packed for your home.","copy_bn":"পরিবারের পছন্দের পণ্য বেছে নিন, যত্ন করে প্যাক করে পৌঁছে দেব।"}
   ]'::jsonb
   or current_settings.hero_slides = '[
     {"image_url":"https://images.unsplash.com/photo-1547592180-85f173990554?auto=format&fit=crop&w=1400&q=82","title_en":"Dinner is ready when you are.","title_bn":"রাতের খাবার প্রস্তুত, যখনই আপনি চান।","copy_en":"Hygienically packed favourites, delivered across Chattogram.","copy_bn":"স্বাস্থ্যসম্মতভাবে প্যাক করা খাবার চট্টগ্রামজুড়ে পৌঁছে যায়।"},
     {"image_url":"https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?auto=format&fit=crop&w=1400&q=82","title_en":"Dinner is ready when you are.","title_bn":"রাতের খাবার প্রস্তুত, যখনই আপনি চান।","copy_en":"Thoughtful portions, packed hygienically and delivered fresh across Chattogram.","copy_bn":"যত্নে পরিমিত খাবার, স্বাস্থ্যসম্মতভাবে প্যাক করে চট্টগ্রামজুড়ে পৌঁছে দিই।"}
   ]'::jsonb;

-- Customers may cancel their own orders only while awaiting confirmation.
-- Use an RPC because direct order updates are intentionally restricted by RLS.
create or replace function public.customer_cancel_order(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_order_user_id uuid;
  v_status text;
  v_payment_status text;
  v_item record;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  select user_id, status, payment_status
    into v_order_user_id, v_status, v_payment_status
  from public.orders
  where id = p_order_id
  for update;

  if not found or v_order_user_id <> v_user_id then
    raise exception 'Order not found';
  end if;
  if v_status <> 'pending_confirmation' then
    raise exception 'Only pending confirmation orders can be cancelled.';
  end if;
  if v_payment_status = 'collected' then
    raise exception 'This order has a collected payment. Contact the store for help.';
  end if;

  -- Restore reserved stock atomically so a cancelled order does not reduce inventory.
  for v_item in
    select product_id, quantity
    from public.order_items
    where order_id = p_order_id and product_id is not null
  loop
    update public.products
      set stock_quantity = stock_quantity + v_item.quantity,
          updated_at = now()
    where id = v_item.product_id;

    insert into public.inventory_movements(product_id, changed_by, quantity_delta, reason)
    values(v_item.product_id, v_user_id, v_item.quantity, 'Customer cancelled order ' || p_order_id::text);
  end loop;

  update public.orders
    set status = 'cancelled',
        cancellation_reason = 'Cancelled by customer',
        updated_at = now()
  where id = p_order_id;

  -- The orders status trigger creates the history entry; add its customer note.
  update public.order_status_history
    set note = 'Cancelled by customer'
  where id = (
    select id
    from public.order_status_history
    where order_id = p_order_id and new_status = 'cancelled'
    order by created_at desc
    limit 1
  );
end;
$$;

revoke all on function public.customer_cancel_order(uuid) from public, anon;
grant execute on function public.customer_cancel_order(uuid) to authenticated;
