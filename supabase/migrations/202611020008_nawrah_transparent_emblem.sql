-- Use the transparent, text-free Nawrah emblem as the storefront logo.
update public.site_settings
set logo_url = '/nawrah-emblem-transparent.png?v=20261102-alpha', updated_at = now()
where id = 'main';
