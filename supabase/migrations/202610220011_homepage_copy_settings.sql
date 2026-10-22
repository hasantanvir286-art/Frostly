-- Optional bilingual overrides for the storefront's editable marketing copy.
-- Empty objects preserve the built-in English/Bangla text until an administrator edits it.
alter table public.site_settings
  add column if not exists homepage_copy jsonb not null default '{}'::jsonb
  check (jsonb_typeof(homepage_copy) = 'object');

-- The settings role may manage storefront copy, just like brand and slider settings.
drop policy if exists site_settings_admin_insert on public.site_settings;
create policy site_settings_admin_insert on public.site_settings
  for insert to authenticated with check (public.is_frostly_settings_manager());

drop policy if exists site_settings_admin_update on public.site_settings;
create policy site_settings_admin_update on public.site_settings
  for update to authenticated using (public.is_frostly_settings_manager())
  with check (public.is_frostly_settings_manager());
