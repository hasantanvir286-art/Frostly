-- Allow each customer to mark one saved delivery address as their default.
alter table public.addresses
  add column if not exists is_default boolean not null default false;

-- Keep one default address per customer at the database level.
create unique index if not exists addresses_one_default_per_user_idx
  on public.addresses(user_id)
  where is_default;
