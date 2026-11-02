-- Use the customer-approved, text-free Nawrah Kitchen emblem across the storefront.
update public.site_settings
set logo_url = '/nawrah-emblem-no-text.png?v=20261102-logo-emblem', updated_at = now()
where id = 'main';
