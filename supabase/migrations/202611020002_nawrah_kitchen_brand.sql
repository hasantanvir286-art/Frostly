-- Set the storefront's new public brand identity and logo.
insert into public.site_settings (id, site_name, logo_url)
values ('main', 'Nawrah Kitchen', '/nawrah-kitchen-mark.svg')
on conflict (id) do update
set site_name = excluded.site_name,
    logo_url = excluded.logo_url,
    updated_at = now();
