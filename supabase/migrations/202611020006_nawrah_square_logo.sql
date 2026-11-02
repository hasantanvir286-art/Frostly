-- Use a square-canvas version of the approved emblem to prevent a stretched badge.
update public.site_settings
set logo_url = '/nawrah-emblem-square.png?v=20261102-square', updated_at = now()
where id = 'main';
