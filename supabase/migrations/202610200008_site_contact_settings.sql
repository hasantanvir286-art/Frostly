-- Contact and payment details editable from Admin > Settings.
alter table public.site_settings
  add column if not exists contact_area text not null default 'Chattogram, Bangladesh',
  add column if not exists contact_phone text not null default '',
  add column if not exists contact_email text not null default '',
  add column if not exists payment_method text not null default 'Cash on Delivery';
