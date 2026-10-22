-- Contact and payment details editable from Admin > Settings.
alter table public.site_settings
  add column if not exists contact_area text not null default 'Chattogram, Bangladesh',
  add column if not exists contact_phone text not null default '',
  add column if not exists contact_email text not null default '',
  add column if not exists payment_method text not null default 'Cash on Delivery';

-- Populate visible demo contact details only when the admin has not entered them.
-- Re-running this migration preserves any non-empty contact values.
update public.site_settings
set contact_phone = case
      when nullif(btrim(contact_phone), '') is null then '01837685147'
      else contact_phone
    end,
    contact_email = case
      when nullif(btrim(contact_email), '') is null then 'hello@frostly.com'
      else contact_email
    end
where id = 'main'
  and (nullif(btrim(contact_phone), '') is null
    or nullif(btrim(contact_email), '') is null);
