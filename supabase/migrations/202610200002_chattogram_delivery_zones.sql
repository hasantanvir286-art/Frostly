-- Enable the two delivery areas and fees supplied by the Frostly owner.
-- Safe to re-run: existing rows with these exact names are updated in place.
insert into public.delivery_zones (area_name, delivery_fee_bdt, is_active)
values
  ('Inside Chattogram Town', 80, true),
  ('Outside Chattogram Town', 120, true)
on conflict (area_name) do update
set delivery_fee_bdt = excluded.delivery_fee_bdt,
    is_active = excluded.is_active;
