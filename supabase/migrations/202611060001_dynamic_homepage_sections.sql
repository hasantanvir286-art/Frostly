-- Storefront section visibility and promotional artwork are public content.
-- The site_settings RLS policies already allow public reads and admin writes.
alter table public.site_settings
  add column if not exists homepage_sections jsonb not null default '{
    "visibility": {
      "trustStrip": true,
      "categories": true,
      "products": true,
      "howItWorks": true,
      "careGuide": true,
      "faq": true,
      "newsletter": true
    },
    "promotions": {
      "family": {
        "visible": true,
        "image_url": "https://images.unsplash.com/photo-1607623814075-e51df1bdc82f?auto=format&fit=crop&w=500&q=80"
      },
      "ready": {
        "visible": true,
        "image_url": "https://images.unsplash.com/photo-1565680018434-b513d5e5fd47?auto=format&fit=crop&w=500&q=80"
      }
    }
  }'::jsonb
  check (jsonb_typeof(homepage_sections) = 'object');

-- Category artwork can be managed independently from product photos.
alter table public.categories
  add column if not exists image_url text not null default '';

update public.site_settings
set homepage_sections = '{
  "visibility": {
    "trustStrip": true,
    "categories": true,
    "products": true,
    "howItWorks": true,
    "careGuide": true,
    "faq": true,
    "newsletter": true
  },
  "promotions": {
    "family": {
      "visible": true,
      "image_url": "https://images.unsplash.com/photo-1607623814075-e51df1bdc82f?auto=format&fit=crop&w=500&q=80"
    },
    "ready": {
      "visible": true,
      "image_url": "https://images.unsplash.com/photo-1565680018434-b513d5e5fd47?auto=format&fit=crop&w=500&q=80"
    }
  }
}'::jsonb
where id = 'main' and homepage_sections = '{}'::jsonb;
