-- Safe page-builder configuration: ordered IDs and approved theme color tokens.
-- Page markup remains in code; admins can only arrange approved sections.
alter table public.site_settings
  add column if not exists page_builder jsonb not null default '{
    "sections": ["hero", "trustStrip", "categories", "products", "offers", "howItWorks", "careGuide", "faq", "newsletter"],
    "theme": {}
  }'::jsonb
  check (jsonb_typeof(page_builder) = 'object');
