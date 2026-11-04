-- Product handling information for informed frozen-food purchases.
alter table public.products
  add column if not exists ingredients_en text not null default '',
  add column if not exists ingredients_bn text not null default '',
  add column if not exists allergens_en text not null default '',
  add column if not exists allergens_bn text not null default '',
  add column if not exists storage_instructions_en text not null default '',
  add column if not exists storage_instructions_bn text not null default '',
  add column if not exists cooking_instructions_en text not null default '',
  add column if not exists cooking_instructions_bn text not null default '';

-- Account-synced favorites. Local browser favorites are merged on sign-in.
create table if not exists public.product_wishlist (
  user_id uuid not null references auth.users(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, product_id)
);

alter table public.product_wishlist enable row level security;
revoke all on public.product_wishlist from anon, authenticated;
grant select, insert, delete on public.product_wishlist to authenticated;

drop policy if exists product_wishlist_select_own on public.product_wishlist;
create policy product_wishlist_select_own
  on public.product_wishlist for select to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists product_wishlist_insert_own on public.product_wishlist;
create policy product_wishlist_insert_own
  on public.product_wishlist for insert to authenticated
  with check (user_id = (select auth.uid()));

drop policy if exists product_wishlist_delete_own on public.product_wishlist;
create policy product_wishlist_delete_own
  on public.product_wishlist for delete to authenticated
  using (user_id = (select auth.uid()));

-- Enable in-session customer order and stock updates through Supabase Realtime.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'orders'
    ) then
      execute 'alter publication supabase_realtime add table public.orders';
    end if;
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'products'
    ) then
      execute 'alter publication supabase_realtime add table public.products';
    end if;
  end if;
end
$$;
