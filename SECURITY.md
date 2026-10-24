# Frostly security notes

## Implemented in this repository

- The Supabase Pages proxy only forwards REST and Storage requests to the configured Frostly Supabase HTTPS host. It rejects cross-origin requests, unsupported methods, redirects, and request bodies over 6 MiB.
- Product, site-asset, and avatar uploads through the production proxy are size-limited and checked against JPEG, PNG, or WebP file signatures. Supabase Storage bucket policies remain the authorization boundary for who may upload.
- Static pages send CSP and baseline browser security headers. The Supabase JavaScript dependency is pinned to version `2.118.0`; the storefront's inline startup script was moved to `startup.js` so the CSP can disallow inline scripts.
- Frontend code uses Supabase query builder parameters rather than building SQL strings. SQL functions that use elevated privileges set a fixed `search_path` and check the current user's role. Database tables use RLS policies to constrain customer and staff access.
- No service-role key or JWT signing secret is included in the browser bundle. The configured anon key is public and non-secret; it relies on RLS for authorization.
- Production console warnings that printed database error details were removed. No source maps or JavaScript package lockfiles are present in the repository.

## Hosted controls still needed

These settings live outside Git and are not enabled by these code changes:

1. **Cloudflare rate limits:** In the Cloudflare zone dashboard, create a rate-limit rule covering `/api/supabase/rest/v1/rpc/` and a separate rule for authentication requests at Supabase if supported by your plan. Start with a moderate per-IP limit and monitor order traffic before tightening it. Free-plan rule fields and limits vary; confirm the options shown for your domain.
2. **Supabase MFA:** Enable TOTP MFA in Supabase Auth settings and build/enable enrollment and challenge flows for staff before requiring AAL2 in RLS. Enforcing AAL2 before staff enroll can lock administrators out. The current app does not yet implement a full staff MFA enrollment/challenge UX or database AAL2 requirement.
3. **Password controls:** Supabase Auth owns password hashing. Configure minimum password length, breached-password protection, email verification, and auth rate limits in the Supabase dashboard. Never store or hash account passwords in this frontend.
4. **JWT signing keys:** Supabase owns JWT signing. Rotate signing keys only through the Supabase project controls and follow its key-rotation guidance; doing so can invalidate sessions and requires checking every deployed client/server integration. Do not place signing or service-role keys in `supabase-config.js`.
5. **Webhook verification:** This repository has no payment-gateway webhook endpoint. Mobile-wallet orders currently record a customer-entered transaction reference for manual review. If a gateway webhook is added, verify its provider signature and timestamp on a server endpoint before changing payment state.
6. **Dependency audit:** The project has no npm manifest or lockfile, so `npm audit` cannot assess a dependency tree. The browser SDK is pinned, but review and update that pinned version deliberately when updating Supabase JS.
7. **Local storage:** The storefront stores cart, wishlist, and language preferences in localStorage; the Supabase browser SDK also persists the signed-in session there. Do not put passwords, private keys, or service-role credentials in browser storage. Moving auth sessions to HttpOnly cookies requires a server-side auth/session architecture.
8. **Custom domains:** HSTS and Cloudflare rate limiting behavior should be reviewed again after adding a custom domain. Keep Cloudflare proxying enabled and restrict allowed origins in Supabase Auth URL configuration to the production and required development URLs.

This is a hardening pass, not a guarantee of complete security. Apply hosted settings, then review the deployed response headers and Supabase policies in the production project.
