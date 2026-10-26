-- Make storefront social profile destinations editable through Admin > Settings.
alter table public.site_settings
  add column if not exists social_links jsonb not null default '{"facebook":"","instagram":"","youtube":""}'::jsonb
  check (jsonb_typeof(social_links) = 'object');

update public.site_settings
set social_links = jsonb_build_object(
  'facebook', coalesce(social_links->>'facebook', ''),
  'instagram', coalesce(social_links->>'instagram', ''),
  'youtube', coalesce(social_links->>'youtube', '')
)
where id = 'main';
