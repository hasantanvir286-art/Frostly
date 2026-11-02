-- Switch storefront branding to the updated scalable vector logo.
update public.site_settings
set logo_url = '/nawrah-kitchen-mark-hd.svg', updated_at = now()
where id = 'main';
