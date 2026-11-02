-- Use the selected clean, text-free Nawrah emblem across the website.
update public.site_settings
set logo_url = '/nawrah-logo-emblem.png?v=20261102-selected', updated_at = now()
where id = 'main';
