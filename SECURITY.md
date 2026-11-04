# Nawrah Kitchen security notes

## Implemented in this repository

- The browser routes Supabase REST and Storage requests through the same-origin Pages Function. It falls back to Supabase only for safe reads, two role-checked read-only RPCs, and the customer review upsert, which remains protected by delivered-order RLS. Order, inventory, and other writes stay behind proxy checks.
- Product, site-asset, and avatar uploads through the production proxy are size-limited and checked against JPEG, PNG, or WebP file signatures. Supabase Storage bucket policies remain the authorization boundary for who may upload.
- Static pages send CSP and baseline browser security headers. The Supabase JavaScript dependency is pinned to version `2.118.0`; the storefront's inline startup script was moved to `startup.js` so the CSP can disallow inline scripts.
- Additional isolation headers prevent cross-origin opener/resource sharing and legacy cross-domain policy files.
- Frontend code uses Supabase query builder parameters rather than building SQL strings. SQL functions that use elevated privileges set a fixed `search_path` and check the current user's role. Database tables use RLS policies to constrain customer and staff access.
- No service-role key or JWT signing secret is included in the browser bundle. The configured anon key is public and non-secret; it relies on RLS for authorization.
- The Admin app now requires Supabase TOTP MFA for staff roles. Database role helpers also require JWT assurance level `aal2` after `202611040017_staff_totp_mfa.sql` is applied.
- Production console warnings that printed database error details were removed. No source maps or JavaScript package lockfiles are present in the repository.

## Deploy the staff MFA change

1. Deploy the application update first so staff see the authenticator setup and verification screen.
2. Apply `supabase/migrations/202611040017_staff_totp_mfa.sql` in the production Supabase SQL Editor. Staff database permissions then require an `aal2` session.
3. Each staff member opens Admin, enrolls an authenticator, and verifies a current six-digit code. Keep a second authenticator on another trusted device. If the only authenticator is lost, recover the account through Supabase Auth as project owner; do not remove the database MFA check as a normal workaround.
4. Keep `supabase/migrations/202611020001_security_hardening.sql` applied too. It removes implicit `PUBLIC`/anonymous RPC execution rights and restores the app's explicit grants.

## Hosted controls still needed

These settings live outside Git and are not enabled by these code changes:

1. **Cloudflare rate limits:** No Cloudflare WAF rate-limit rule is configured in this repository. Add one for API requests when using a custom domain/zone, or move the Pages proxy behind a Worker with a Rate Limiting binding. Start with a moderate limit and monitor legitimate orders. Cloudflare's in-Worker counters are approximate and per location; strict global quotas require shared coordination.
2. **Auth throttling and passwords:** Configure Supabase Auth rate limits, email verification, minimum password length, and breached-password protection. Supabase Auth owns password hashing; never store or hash passwords in this frontend.
3. **JWT signing keys:** Supabase owns JWT signing. Rotate signing keys only through the Supabase project controls and follow its key-rotation guidance; doing so can invalidate sessions and requires checking every deployed client/server integration. Do not place signing or service-role keys in `supabase-config.js`.
4. **Webhook verification:** This repository has no payment-gateway webhook endpoint. Mobile-wallet orders currently record a customer-entered transaction reference for manual review. If a gateway webhook is added, verify its provider signature and timestamp on a server endpoint before changing payment state.
5. **Dependency audit:** The project has no npm manifest or lockfile, so `npm audit` cannot assess a dependency tree. The browser SDK is pinned, but review and update that pinned version deliberately when updating Supabase JS.
6. **Local storage:** The storefront stores cart, wishlist, and language preferences in localStorage; the Supabase browser SDK also persists the signed-in session there. Do not put passwords, private keys, or service-role credentials in browser storage. Moving auth sessions to HttpOnly cookies requires a server-side auth/session architecture.
7. **Custom domains:** HSTS and Cloudflare rate limiting behavior should be reviewed again after adding a custom domain. Keep Cloudflare proxying enabled and restrict allowed origins in Supabase Auth URL configuration to the production and required development URLs.

This is a hardening pass, not a guarantee of complete security. Apply hosted settings, then review the deployed response headers and Supabase policies in the production project.
