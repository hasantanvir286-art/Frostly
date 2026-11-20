-- Keep public review rendering available without exposing customer/order IDs.
-- Authenticated customers may still read their own review rows for editing.
revoke select on public.product_reviews from PUBLIC, anon, authenticated;
revoke select (id, product_id, user_id, order_id, rating, review_text, created_at)
  on public.product_reviews from PUBLIC, anon, authenticated;

grant select (product_id, rating, review_text, created_at)
  on public.product_reviews to anon;
grant select (id, product_id, user_id, order_id, rating, review_text, created_at)
  on public.product_reviews to authenticated;

drop policy if exists product_reviews_public_read on public.product_reviews;
drop policy if exists product_reviews_owner_read on public.product_reviews;
create policy product_reviews_owner_read on public.product_reviews
  for select to authenticated
  using (user_id = auth.uid());

create or replace view public.product_reviews_public
with (security_barrier = true)
as
  select product_id, rating, review_text, created_at
  from public.product_reviews;

revoke all on public.product_reviews_public from PUBLIC, anon, authenticated;
grant select on public.product_reviews_public to anon, authenticated;

comment on view public.product_reviews_public is
  'Public review projection; excludes customer and order identifiers.';
