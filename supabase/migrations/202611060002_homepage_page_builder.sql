-- Safe page-builder configuration: ordered sections, custom page/block data,
-- and approved theme/layout tokens rendered by the storefront component library.
alter table public.site_settings
  add column if not exists page_builder jsonb not null default '{
    "sections": ["hero", "trustStrip", "categories", "products", "offers", "howItWorks", "careGuide", "faq", "newsletter"],
    "theme": {}
  }'::jsonb
  check (jsonb_typeof(page_builder) = 'object');
