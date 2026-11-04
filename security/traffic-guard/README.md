# Nawrah Kitchen API rate limit and temporary IP bans

This separate Cloudflare Worker protects requests routed through the Pages Supabase proxy. It uses a Durable Object per hashed client IP so counters and temporary bans are coordinated consistently. Raw IP addresses are not written to durable storage.

## Policy

- Supabase REST API: 120 requests per IP per 60-second window.
- Supabase Storage API: 30 requests per IP per 60-second window.
- Repeated over-limit activity in three separate windows within 15 minutes triggers a 30-minute temporary ban from the proxied API.
- A ban ends automatically. It does not block cached/static Pages assets or direct requests sent to Supabase; configure Supabase Auth throttling separately. For whole-site IP blocks, use Cloudflare WAF after adding a custom domain.

## Deploy and connect

1. Install Node.js and Wrangler, then open PowerShell in `security/traffic-guard`. Sign in to Cloudflare and deploy the Worker:

   ```powershell
   npx wrangler login
   npx wrangler deploy
   ```

2. Create a long random secret and set it on the Worker:

   ```powershell
   npx wrangler secret put GUARD_SHARED_SECRET
   ```

   Paste the same secret when prompted in the Cloudflare dashboard under the Pages project’s **Settings → Variables and Secrets** as `FROSTLY_GUARD_SECRET` (mark it secret).

3. In **Workers & Pages → frostly → Settings → Bindings**, add a **Service binding** named `SECURITY_GUARD` and select `nawrah-traffic-guard`.

4. Add `REQUIRE_TRAFFIC_GUARD` with value `true` to the Pages project’s production environment. Redeploy Pages so the binding and variables are available to Functions.

5. Push/deploy the Pages proxy change. Once it is live, requests are rejected with HTTP 429 when limited, and the guard fails closed with HTTP 503 if the required protection binding becomes unavailable.

Do not place either secret in Git, a `.env` file committed to the repository, or browser code. Configure preview bindings separately if preview deployments must use the protected API.

Wrangler must be version 4.36.0 or newer for this Durable Object configuration. Durable Objects are available on Cloudflare Free with usage limits; review the account’s current limits before expecting high traffic.
