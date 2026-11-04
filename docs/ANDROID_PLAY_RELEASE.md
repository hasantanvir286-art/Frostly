# Nawrah Kitchen Android release preparation

## Current state

The repository currently provides an installable PWA. It is not yet a signed Android App Bundle and has not been submitted to Google Play. The PWA assets are already in icons/nawrah-gold-192.png and icons/nawrah-gold-512.png.

For Play Store distribution, package the deployed site as a Trusted Web Activity (TWA), then generate and sign an Android App Bundle (AAB). A TWA requires HTTPS and a Digital Asset Links file on the website at /.well-known/assetlinks.json, containing the final Android package ID and signing certificate fingerprint.

## Store listing draft

- **Display name:** Nawrah Kitchen
- **Suggested package ID:** com.nawrahkitchen.app — provisional. Choose and verify the final ID before creating the Play Console app; package IDs are permanent for a listing.
- **Category:** Food & Drink
- **Short description:** Frozen favourites delivered across Chattogram, Bangladesh.
- **Long description:** Shop frozen snacks, fish, meat, and family favourites from Nawrah Kitchen. Browse the live product catalogue, check current prices and availability, save favourites, place delivery orders, and follow order status from your account. Delivery areas, fees, and available payment methods are shown at checkout. Contact Nawrah Kitchen through the support details published in the app.
- **Icon:** Use the existing 512 × 512 PNG in icons/nawrah-gold-512.png. Inspect the final listing preview in Play Console before publishing.
- **Screenshots:** Capture current English and Bangla storefront, product detail, cart, order history, and admin screens on actual Android devices. Do not use mock order or customer data in public listing images.

## Privacy and Data safety

The public policy page is https://frostly-400.pages.dev/privacy.html. Confirm that it is current, names the real business and support contact, is publicly accessible, and accurately describes the production app before submitting. Google Play requires a privacy-policy link on the store listing and within the app when the app handles sensitive user data. See Google's [app review preparation requirements](https://support.google.com/googleplay/android-developer/answer/9859455).

Review every enabled feature and SDK before completing Play Console's [Data safety form](https://support.google.com/googleplay/android-developer/answer/10787469). The site can process account email, profile name and phone, delivery addresses, order contents and status, payment method and mobile-payment reference, profile image, customer reviews, newsletter subscription, Google sign-in data, saved product favorites, and product stock-alert requests. Supabase stores application data; Google OAuth and email delivery may be involved. Confirm the actual retention, deletion, sharing, and encryption practices in the live project; this list is a review checklist, not a completed disclosure.

## Build and release gates

1. Deploy the final website to HTTPS and verify checkout, account, order history, privacy policy, support details, and both languages on Android.
2. Select the permanent package ID and create the TWA wrapper with Bubblewrap or another maintained Android TWA tool.
3. Build a signed AAB. Keep the upload key private and backed up. Configure Play App Signing in Play Console.
4. Publish assetlinks.json using the package ID and SHA-256 fingerprint for the certificate Google Play uses to sign the distributed app. Verify Android opens the domain in the full-screen TWA without a browser toolbar.
5. Complete the current target API, content rating, Data safety, privacy, screenshots, and contact sections in Play Console. As of August 31, 2026, new apps and updates must target Android 16 (API 36) or higher; check Google's [target API requirements](https://support.google.com/googleplay/android-developer/answer/11926878) at submission time.
6. Run an internal/closed test with real testers and test accounts. Personal developer accounts created after November 13, 2023 must meet Google's closed-testing requirement: at least 12 testers opted in continuously for 14 days before applying for production access. See [Google's testing requirements](https://support.google.com/googleplay/android-developer/answer/14151465).
7. Submit for review only after the production order flow and support contacts are verified.

Do not upload a keystore, service-role key, OAuth client secret, or other private credential to GitHub.
