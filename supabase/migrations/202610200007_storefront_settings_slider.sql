-- Editable storefront brand and homepage hero slides.
create table if not exists public.site_settings (
  id text primary key default 'main' check (id = 'main'),
  site_name text not null default 'Frostly',
  logo_url text not null default '',
  hero_slides jsonb not null default '[]'::jsonb check (jsonb_typeof(hero_slides) = 'array'),
  updated_at timestamptz not null default now(),
  updated_by uuid references public.profiles(id)
);

alter table public.site_settings enable row level security;
revoke all on public.site_settings from anon, authenticated;
grant select on public.site_settings to anon, authenticated;
grant insert, update on public.site_settings to authenticated;

drop policy if exists site_settings_public_read on public.site_settings;
create policy site_settings_public_read on public.site_settings
  for select to anon, authenticated using (true);

drop policy if exists site_settings_admin_insert on public.site_settings;
create policy site_settings_admin_insert on public.site_settings
  for insert to authenticated with check (public.is_frostly_admin());

drop policy if exists site_settings_admin_update on public.site_settings;
create policy site_settings_admin_update on public.site_settings
  for update to authenticated using (public.is_frostly_admin())
  with check (public.is_frostly_admin());

insert into public.site_settings (id, site_name, hero_slides)
values (
  'main',
  'Frostly',
  '[
    {"image_url":"https://images.unsplash.com/photo-1510130387422-82bed34b37e9?auto=format&fit=crop&w=1200&q=85","title_en":"Premium Frozen Food Now in Chattogram","title_bn":"প্রিমিয়াম ফ্রোজেন খাবার এখন চট্টগ্রামে","copy_en":"Safe, delicious, quality frozen food for your family.","copy_bn":"আপনার পরিবারের জন্য নিরাপদ, সুস্বাদু ও মানসম্মত ফ্রোজেন খাবার।"},
    {"image_url":"https://images.unsplash.com/photo-1604503468506-a8da13d82791?auto=format&fit=crop&w=1200&q=85","title_en":"Delicious favourites, delivered frozen fresh","title_bn":"পরিবারের পছন্দের খাবার, ফ্রোজেন সতেজতায় পৌঁছে যাবে","copy_en":"Choose from family favourites, carefully packed for your home.","copy_bn":"পরিবারের পছন্দের পণ্য বেছে নিন, যত্ন করে প্যাক করে পৌঁছে দেব।"}
  ]'::jsonb
)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('frostly-site-assets', 'frostly-site-assets', true, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists frostly_site_assets_public_read on storage.objects;
create policy frostly_site_assets_public_read on storage.objects
  for select to anon, authenticated using (bucket_id = 'frostly-site-assets');

drop policy if exists frostly_site_assets_admin_insert on storage.objects;
create policy frostly_site_assets_admin_insert on storage.objects
  for insert to authenticated with check (bucket_id = 'frostly-site-assets' and public.is_frostly_admin());

drop policy if exists frostly_site_assets_admin_update on storage.objects;
create policy frostly_site_assets_admin_update on storage.objects
  for update to authenticated
  using (bucket_id = 'frostly-site-assets' and public.is_frostly_admin())
  with check (bucket_id = 'frostly-site-assets' and public.is_frostly_admin());

drop policy if exists frostly_site_assets_admin_delete on storage.objects;
create policy frostly_site_assets_admin_delete on storage.objects
  for delete to authenticated using (bucket_id = 'frostly-site-assets' and public.is_frostly_admin());
