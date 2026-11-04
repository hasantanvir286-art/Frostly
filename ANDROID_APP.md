# Nawrah Kitchen on Android

The website is packaged as an installable Progressive Web App (PWA) with the gold N and ice emblem on a navy app tile. Customers use the full storefront; signed-in staff use the existing role-protected admin dashboard. Both use the same Supabase database and permissions as the website.

## Publish and install

1. Push the project to the connected GitHub branch and wait for the Cloudflare Pages deployment to succeed. The PWA requires HTTPS; the production `pages.dev` site already provides it.
2. On an Android phone, open the deployed storefront in Chrome.
3. Tap **Install app** in the top bar if it appears, or open Chrome's menu and choose **Install app** / **Add to Home screen**.
4. Launch **Nawrah** from the home screen. Use the account icon to sign in or create a customer account.
5. Superadmins and authorized staff can open **Admin dashboard** from the installed app's icon shortcuts (long-press the app icon), or open the existing admin dashboard URL in Chrome. Existing database role checks still control access.

If Nawrah was installed before the gold icon update, remove the old home-screen installation and install it again after the latest deployment so Android picks up the new icon.

## What works in the app

- Customer catalog, search, English/Bangla, cart, checkout, account, order history, cancellation rules, and verified reviews.
- Admin dashboard, according to the signed-in staff member's existing Supabase role.
- Offline app shell and previously loaded static files. Product data, sign-in, checkout, order management, image uploads, and other database actions need an internet connection.

No separate mobile database or staff login has been introduced. The app uses the current site's Supabase configuration and server-side database permissions.
