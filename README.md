# Frostly

A responsive storefront based on the supplied Frostly visual reference. The workspace contained no existing application, so this remains plain HTML, CSS, and JavaScript and does not require a build step. Supabase's browser SDK is loaded from its official CDN for optional authentication and database features.

## Run locally

Open `index.html` in a browser, or run a local static server from this folder:

```sh
python -m http.server 8000
```

Then visit `http://localhost:8000`. Product imagery and Google Fonts are loaded from external services, so they require internet access. Local storage keeps the sample cart, wishlist, and language preference in the current browser.

## What works in this prototype

- Responsive Bangla storefront with category cards, search, sample products, promo panels, FAQ, storage guidance, and complete footer.
- English-default bilingual storefront with synchronized header and footer language dropdowns; the selected language is saved in the browser.
- Client-side demo cart with quantity controls and totals, persisted in browser local storage.
- Client-side wishlist and Bangla/English product-name switch.
- Customer assistant panel with catalog-grounded answers from the local sample data. It is not an OpenAI integration.
- A responsive admin console at `admin.html` with live metrics, order management, catalog editing, inventory, delivery areas, and customer summaries.
- Supabase email/password sign-up and sign-in, editable customer profiles with photo uploads and password recovery, a separate customer order drawer, a protected admin dashboard with live order/inventory metrics, and server-validated Cash on Delivery checkout are implemented behind Supabase configuration and the migrations below.
- Newsletter signups remain disabled until a newsletter action is wired to the database.

Products, prices, and stock are explicitly demo data. Contact values are placeholders. Reviews are identified as demo content. No authentic customer, company, or payment claims are made.

## Connect Supabase

1. Create a Supabase project and open **Project Settings → API**. Copy the Project URL and the public **anon/publishable** key into `supabase-config.js`. This file is loaded by the browser: never put a `service_role` or secret key in it.
2. In the Supabase SQL Editor, run [`supabase/migrations/202610200001_frostly_core.sql`](supabase/migrations/202610200001_frostly_core.sql). It creates Auth profiles, bilingual demo catalog, customer-owned data, orders, inventory/status history, restrictive RLS policies, and database functions.
3. Run [`supabase/migrations/202610200002_chattogram_delivery_zones.sql`](supabase/migrations/202610200002_chattogram_delivery_zones.sql) to enable Inside Chattogram Town (৳80) and Outside Chattogram Town (৳120). It is safe to re-run.
4. Run [`supabase/migrations/202610200003_admin_inventory_adjustment.sql`](supabase/migrations/202610200003_admin_inventory_adjustment.sql) to enable secure inventory adjustments with movement history from the admin dashboard.
5. Run [`supabase/migrations/202610200004_customer_profile_settings.sql`](supabase/migrations/202610200004_customer_profile_settings.sql) to add profile phone/photo fields and secure customer avatar uploads.
6. Run [`supabase/migrations/202610200005_default_delivery_address.sql`](supabase/migrations/202610200005_default_delivery_address.sql) to enable a customer's default saved delivery address.
7. Run [`supabase/migrations/202610200006_admin_product_image_uploads.sql`](supabase/migrations/202610200006_admin_product_image_uploads.sql) to enable public product image delivery and admin-only uploads.
8. Run [supabase/migrations/202610200007_storefront_settings_slider.sql](supabase/migrations/202610200007_storefront_settings_slider.sql) to enable dashboard editing for the storefront name, logo, and homepage slides.
9. Run [supabase/migrations/202610200008_site_contact_settings.sql](supabase/migrations/202610200008_site_contact_settings.sql) to add editable storefront contact and payment details.
10. Create a customer account through Frostly. Confirm its email if Supabase email confirmation is enabled.
11. Bootstrap the first administrator from the Supabase SQL Editor. Replace the email with the administrator account created in step 10:

   ```sql
   begin;
   alter table public.profiles disable trigger protect_frostly_profile_role;
   update public.profiles
   set role = 'admin'
   where id = (select id from auth.users where email = 'admin@example.com');
   alter table public.profiles enable trigger protect_frostly_profile_role;
   commit;
   ```

   Verify the `UPDATE 1` result. Do not expose a public admin-registration flow. The admin dashboard checks the profile role, while RLS and database functions enforce access independently.
7. Replace all demo catalog rows and contact placeholders with verified Frostly business information before taking live orders. Confirm Supabase Auth email, site URL, and redirect settings for your local and production domains.

The admin console includes live order metrics and status updates, catalog editing, inventory adjustments with a ledger, delivery-zone and fee management, and customer summaries derived from orders. The COD RPC `create_cod_order` requires an authenticated customer, locks products, reads current prices and stock, validates the configured delivery zone, records immutable order item snapshots, decrements stock once, and uses an idempotency ID on retries. Admin status changes are checked against permitted transitions and logged. The first administrator must be bootstrapped through the trusted SQL Editor.

## Still to build or configure

This is not a Next.js/server-rendered application. Address-book editing UI, delivery staff screens/assignment UI, advanced reporting, a production customer-service policy set, OpenAI assistants, and newsletter signup storage are not yet implemented. The database includes initial operational tables for some of those later features. Demo products and images must be replaced; no real business contact, inventory, or review data is included. Review the migration and delivery rules before using the project with real customers.

Only the public Supabase URL and anon/publishable key belong in `supabase-config.js`. There is no service-role key, AI key, or online-payment credential in the browser.
