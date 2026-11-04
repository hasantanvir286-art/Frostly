-- Optional public delivery hours shown in the storefront footer.
alter table public.site_settings
  add column if not exists delivery_hours text not null default '';

-- Customers may request an in-site alert for a product that is out of stock.
-- Alerts are private to their owner. They are surfaced the next time the customer
-- visits after stock is replenished; this migration does not send email or push.
create table if not exists public.product_stock_alerts (
  user_id uuid not null references auth.users(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  created_at timestamptz not null default now(),
  notified_at timestamptz,
  primary key (user_id, product_id)
);

alter table public.product_stock_alerts enable row level security;
revoke all on public.product_stock_alerts from anon, authenticated;
grant select, insert, update on public.product_stock_alerts to authenticated;

drop policy if exists product_stock_alerts_select_own on public.product_stock_alerts;
create policy product_stock_alerts_select_own
  on public.product_stock_alerts for select to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists product_stock_alerts_insert_own on public.product_stock_alerts;
create policy product_stock_alerts_insert_own
  on public.product_stock_alerts for insert to authenticated
  with check (user_id = (select auth.uid()));

drop policy if exists product_stock_alerts_update_own on public.product_stock_alerts;
create policy product_stock_alerts_update_own
  on public.product_stock_alerts for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
