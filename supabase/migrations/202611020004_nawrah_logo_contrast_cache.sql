-- Bust cached logo URLs after updating the artwork and contrast treatment.
update public.site_settings
set logo_url = '/nawrah-kitchen-mark-hd.svg?v=20261102-contrast', updated_at = now()
where id = 'main';
