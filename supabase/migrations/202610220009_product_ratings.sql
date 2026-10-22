create table if not exists public.product_reviews (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  order_id uuid not null references public.orders(id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  review_text text not null default '' check (char_length(review_text) <= 500),
  created_at timestamptz not null default now(),
  unique (product_id, user_id)
);

create index if not exists product_reviews_product_created_idx
  on public.product_reviews(product_id, created_at desc);

alter table public.product_reviews enable row level security;
revoke all on public.product_reviews from anon, authenticated;
grant select on public.product_reviews to anon, authenticated;
grant insert, update on public.product_reviews to authenticated;

drop policy if exists product_reviews_public_read on public.product_reviews;
create policy product_reviews_public_read on public.product_reviews
  for select to anon, authenticated using (true);

drop policy if exists product_reviews_verified_insert on public.product_reviews;
create policy product_reviews_verified_insert on public.product_reviews
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and exists (
      select 1
      from public.orders o
      join public.order_items oi on oi.order_id = o.id
      where o.id = product_reviews.order_id
        and o.user_id = auth.uid()
        and o.status = 'delivered'
        and oi.product_id = product_reviews.product_id
    )
  );

drop policy if exists product_reviews_verified_update on public.product_reviews;
create policy product_reviews_verified_update on public.product_reviews
  for update to authenticated
  using (user_id = auth.uid())
  with check (
    user_id = auth.uid()
    and exists (
      select 1
      from public.orders o
      join public.order_items oi on oi.order_id = o.id
      where o.id = product_reviews.order_id
        and o.user_id = auth.uid()
        and o.status = 'delivered'
        and oi.product_id = product_reviews.product_id
    )
  );
