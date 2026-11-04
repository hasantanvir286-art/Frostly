# Nawrah Kitchen production go-live checklist

Use this checklist before accepting customer orders. Apply database changes to a staging project first, verify them, and then repeat against production. Never put Supabase service-role keys, OAuth secrets, signing keys, or traffic-guard secrets in Git or browser code.

## 1. Database and access

- On an existing project, check which migrations are already applied and run only the missing ones. For a fresh project, apply 017, 018, and 019 in order. Migration 017 enables staff TOTP requirements; deploy the matching admin code before applying it or staff may be unable to enroll.
- Confirm product details are populated from verified packaging/supplier information. Blank detail fields stay omitted from the product page.
- Confirm the `product_wishlist` table has RLS enabled and own-row policies; customers should only read or mutate their own favorites.
- Confirm `orders` and `products` appear in the `supabase_realtime` publication. Migration 019 adds them when the standard publication exists.
- In Supabase Auth, set the production Site URL, allow-list production and local redirect URLs, configure signup confirmation, and set appropriate Auth rate limits.
- Confirm every staff account has the minimum role needed and completes TOTP enrollment. Test customer, staff, and superadmin permissions using separate accounts.

## 2. Cloudflare and secrets

- Connect Pages to the intended GitHub repository and production branch. For this static project, use the repository root, no build command, and `/` as the output directory.
- Verify the Pages Functions directory is deployed and its Supabase proxy can reach the configured Supabase project. Keep only the public Supabase URL and anon/publishable key in browser configuration.
- If rate limiting/IP bans are required, complete every step in `security/traffic-guard/README.md`: deploy the guard Worker, set both matching secrets in their proper server environments, create the `SECURITY_GUARD` service binding, and set `REQUIRE_TRAFFIC_GUARD=true`. Verify expected throttling and fail-closed behavior before launch.
- Use Cloudflare preview deployments and a Supabase staging project for checks; do not validate by creating fake production customer orders.
- After GitHub reports a successful Pages deployment, open the deployed site in a private window and confirm `index.html`, the Admin console, CSS, and JavaScript use the new version query strings.

## 3. Customer experience checks

- Follow `ORDER_FLOW_RELEASE_CHECKLIST.md` with test accounts and a staging order.
- Verify live order-status toasts and back-in-stock alerts with the customer signed in and the page open. These are in-site notifications; no email, SMS, or push message is sent.
- Verify favorites merge from the guest browser into the signed-in account and appear on a second device after login.
- Verify each product's English/Bangla ingredients, allergen, storage, and cooking details. Do not make unverified food-safety claims.
- Change an order status as staff and use **WhatsApp update** to review the prefilled draft. Staff must send it manually; the app does not send WhatsApp messages in the background.
- Confirm cancellation cutoff, delivery fee, payment instructions, contact details, policy pages, and support contact reflect the actual business.

## 4. Android release gate

- Follow `ANDROID_APP.md` for PWA installation and `ANDROID_PLAY_RELEASE.md` for a Play Store release. A website deployment does not publish an Android app.
- Before Play submission, choose the permanent package ID, generate and securely back up the signing key, publish the matching Digital Asset Links file, and complete current Play Console review/testing/Data safety requirements.

## Rollback

If a frontend deploy breaks the storefront, use Cloudflare Pages → Deployments to restore the last known-good deployment. Database migrations are not automatically rolled back by a frontend rollback; apply a reviewed corrective migration instead of deleting live data.
