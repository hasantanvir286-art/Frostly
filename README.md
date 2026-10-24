# Frostly

Full project architecture, database, security and deployment notes are in [`docs/PROJECT_DOCUMENTATION.md`](docs/PROJECT_DOCUMENTATION.md). Customer and administrator instructions are in [`docs/USER_MANUAL.md`](docs/USER_MANUAL.md).

A responsive storefront based on the supplied Frostly visual reference. The workspace contained no existing application, so this remains plain HTML, CSS, and JavaScript and does not require a build step. Supabase's browser SDK is loaded from its official CDN for optional authentication and database features.

## Run locally

Open `index.html` in a browser, or run a local static server from this folder:

```sh
python -m http.server 8000
```

Then visit `http://localhost:8000`. Product imagery and Google Fonts are loaded from external services, so they require internet access. Local storage keeps the sample cart, wishlist, and language preference in the current browser.

## Storefront and admin features

- Responsive bilingual storefront. Products and categories load from the live Supabase catalog; an empty catalog stays empty instead of showing sample products as real stock.
- English-default bilingual storefront with synchronized header and footer language dropdowns; the selected language is saved in the browser.
- Customer cart and wishlist with quantity controls and totals, persisted in browser local storage.
- Client-side wishlist and Bangla/English product-name switch.
- Customer assistant panel with catalog-grounded answers from the local sample data. It is not an OpenAI integration.
- A responsive admin console at `console-a84d8903f59b4d358c8cc927633a11f6.html` with live metrics, order management, catalog editing, inventory, delivery areas, and customer summaries.
- Supabase email/password sign-up and sign-in, editable customer profiles with photo uploads and password recovery, a separate customer order drawer, a protected admin dashboard with live order/inventory metrics, and server-validated checkout are implemented behind Supabase configuration and the migrations below. Checkout supports Cash on Delivery and manual bKash/Nagad/Rocket transfers; wallet transfers require a transaction ID and independent staff verification and are not processed by an integrated payment gateway.
- On Cloudflare Pages, Supabase Auth, Data API, Storage API, and Functions HTTP calls go through the same-origin `/api/supabase/*` Pages Function. Set `FROSTLY_SUPABASE_URL` in Pages variables if the project URL changes; otherwise the function uses the configured Frostly project. `_routes.json` limits Function invocation to proxy requests, keeping static assets on the normal Pages path. Local HTTP servers continue to call Supabase directly.
- Newsletter form saves unique email subscriptions in the existing `newsletter_subscriptions` table.

The public catalog is database-backed. Replace any seed catalog rows and demo images with verified products, prices, and stock before taking live orders. The visual layout is shipped in the frontend; the dashboard edits the brand, logo, hero slides, bilingual homepage copy, contact/payment details, product catalog, categories, delivery zones, and staff roles.

## Connect Supabase

1. Create a Supabase project and open **Project Settings → API**. Copy the Project URL and the public **anon/publishable** key into `supabase-config.js`. This file is loaded by the browser: never put a `service_role` or secret key in it.
2. In the Supabase SQL Editor, run [`supabase/migrations/202610200001_frostly_core.sql`](supabase/migrations/202610200001_frostly_core.sql). It creates Auth profiles, bilingual demo catalog, customer-owned data, orders, inventory/status history, restrictive RLS policies, and database functions.
3. Run [`supabase/migrations/202610200002_chattogram_delivery_zones.sql`](supabase/migrations/202610200002_chattogram_delivery_zones.sql) to enable Inside Chattogram Town (৳80) and Outside Chattogram Town (৳120). It is safe to re-run.
4. Run [`supabase/migrations/202610200003_admin_inventory_adjustment.sql`](supabase/migrations/202610200003_admin_inventory_adjustment.sql) to enable secure inventory adjustments with movement history from the admin dashboard.
5. Run [`supabase/migrations/202610200004_customer_profile_settings.sql`](supabase/migrations/202610200004_customer_profile_settings.sql) to add profile phone/photo fields and secure customer avatar uploads.
6. Run [`supabase/migrations/202610200005_default_delivery_address.sql`](supabase/migrations/202610200005_default_delivery_address.sql) to enable a customer's default saved delivery address.
7. Run [`supabase/migrations/202610200006_admin_product_image_uploads.sql`](supabase/migrations/202610200006_admin_product_image_uploads.sql) to enable public product image delivery and admin-only uploads.
8. Run [supabase/migrations/202610200007_storefront_settings_slider.sql](supabase/migrations/202610200007_storefront_settings_slider.sql) to enable dashboard editing for the storefront name, logo, and homepage slides.
9. Run [supabase/migrations/202610200008_site_contact_settings.sql](supabase/migrations/202610200008_site_contact_settings.sql) to add editable storefront contact and payment details. It fills blank contact fields with sample values `01837685147` and `hello@frostly.com`, while preserving any non-empty values. Replace the samples in Admin → Settings with your real details.
10. Run [supabase/migrations/202610220009_product_ratings.sql](supabase/migrations/202610220009_product_ratings.sql) to add verified delivered-order product reviews.
11. Run [supabase/migrations/202610220010_staff_roles_and_user_management.sql](supabase/migrations/202610220010_staff_roles_and_user_management.sql) to enable superadmin, admin, order manager, stock manager, catalog manager, delivery manager, and settings manager roles. It promotes the earliest existing admin to superadmin when no superadmin exists.
12. Run [supabase/migrations/202610220011_homepage_copy_settings.sql](supabase/migrations/202610220011_homepage_copy_settings.sql) to enable bilingual homepage copy editing from Admin → Settings.
13. Run [supabase/migrations/202610220012_superadmin_delete_customer.sql](supabase/migrations/202610220012_superadmin_delete_customer.sql) to enable superadmin-only customer account deletion.
14. Run [supabase/migrations/202610220013_superadmin_delete_staff.sql](supabase/migrations/202610220013_superadmin_delete_staff.sql) to enable superadmin-only staff account deletion with role protections.
15. Run [supabase/migrations/202610220014_manual_mobile_payments.sql](supabase/migrations/202610220014_manual_mobile_payments.sql) to enable configurable COD, bKash, Nagad, and Rocket checkout methods, wallet receiving numbers, transaction IDs, and pending manual verification.
16. Run [supabase/migrations/202610240015_order_manager_status_access.sql](supabase/migrations/202610240015_order_manager_status_access.sql) to ensure order managers, admins, and superadmins can update order status on existing databases.
17. Create a customer account through Frostly. Confirm its email if Supabase email confirmation is enabled.
18. If the project has no existing administrator/superadmin, bootstrap the first superadmin through the Supabase SQL Editor. Replace the email with the trusted account created in step 17:

   ```sql
   begin;
   alter table public.profiles disable trigger protect_frostly_profile_role;
   update public.profiles
   set role = 'superadmin'
   where id = (select id from auth.users where email = 'admin@example.com');
   alter table public.profiles enable trigger protect_frostly_profile_role;
   commit;
   ```

   Verify the `UPDATE 1` result. Do not expose a public staff-registration flow. The admin dashboard checks profile roles, while RLS and database functions enforce access independently.
19. Replace any sample catalog rows with verified Frostly products, images, prices, and stock before taking live orders. Confirm Supabase Auth email, site URL, and redirect settings for your local and production domains. Configure and test active delivery areas, payment method toggles, and wallet receiving numbers.

For email confirmation, set **Supabase → Authentication → URL Configuration → Site URL** to `https://frostly-400.pages.dev` (or your custom domain) and allow-list the production URL and local development URL under **Redirect URLs**. The storefront now displays a code-entry screen after signup. To send a 6-digit code, open **Authentication → Email Templates → Confirm signup**, set the subject to `Your Frostly verification code`, and use this body (do not use `{{ .ConfirmationURL }}` in the confirmation template):

   ```html
   <h2>Verify your Frostly account</h2>
   <p>Enter this 6-digit code on Frostly to activate your account:</p>
   <p style="font-size:28px;font-weight:700;letter-spacing:8px">{{ .Token }}</p>
   <p>If you did not request an account, you can ignore this email.</p>
   ```

Supabase stores this email template in the project dashboard, so pushing code alone does not change it. Existing confirmation emails keep their old links; test by registering with a new email after the template and Pages deployment are updated. Supabase requires redirect targets to match the allowed URL list. See [Supabase redirect URL settings](https://supabase.com/docs/guides/auth/redirect-urls) and [email templates](https://supabase.com/docs/guides/auth/auth-email-templates).

The admin console includes live order metrics and status updates, product and category editing, inventory adjustments with a ledger, delivery-zone and fee management, storefront settings, and superadmin-only staff role management. Roles are enforced by RLS and database functions, not only by hidden navigation. Superadmins can assign existing accounts as superadmin, admin, order manager, stock manager, catalog manager, delivery manager, settings manager, delivery staff, or customer. Admin profile email changes require password reauthentication and confirmation through Supabase Auth.

## Still to build or configure

This is a static frontend backed by Supabase, not a server-rendered application. Newsletter subscriptions are captured in Supabase but there is no subscriber-management screen yet. Homepage copy, FAQ wording, brand, slider, contact, products, categories, orders, delivery zones, and ratings are database-backed; visual layout and service behavior remain code-managed. Delivery staff assignment screens and a production AI assistant are not implemented. Review the database setup, replace any seeded sample products, and confirm business policies before using the project with real customers.

Product ratings are added by `supabase/migrations/202610220009_product_ratings.sql`. Run this migration in the Supabase SQL Editor before enabling customer ratings. Only customers with a delivered order containing that product may submit or update one rating per product; public visitors can read ratings and reviews.

Only the public Supabase URL and anon/publishable key belong in `supabase-config.js`. There is no service-role key, AI key, or online-payment credential in the browser.
