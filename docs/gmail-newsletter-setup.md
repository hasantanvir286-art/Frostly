# Frostly newsletter setup

The storefront can save email subscriptions in Supabase. Visitors may type an email address or choose **Continue with Google** and consent using the Google account email. Administrators with the `superadmin`, `admin`, or `settingsmanager` role can send campaigns from the dashboard settings page.

## 1. Apply the Supabase migration

Open Supabase → SQL Editor, paste the complete contents of `supabase/migrations/202610250001_gmail_newsletter.sql`, and run it. This adds opt-out tracking and a safe subscription RPC. Deploy the website only after the SQL succeeds.

## 2. Allow the Google sign-in return URL

In Supabase → Authentication → URL Configuration, make sure the production redirect allow-list includes:

```text
https://frostly-400.pages.dev/**
```

The Google button uses the existing Google sign-in provider and returns to `https://frostly-400.pages.dev/?newsletter=google`. The visitor is subscribed only after explicitly selecting the button and completing Google sign-in. The site does not receive Gmail mailbox access for this flow.

## 3. Configure the Gmail sender in Google Cloud

Campaign sending is separate from customer Google sign-in. Create a Google Cloud OAuth client for this purpose, enable the Gmail API, and authorize the Gmail account that will send Frostly emails. The OAuth scope must be:

```text
https://www.googleapis.com/auth/gmail.send
```

Create a refresh token for that OAuth client and sender account. Keep the client secret and refresh token private. If Google leaves the OAuth consent screen in Testing mode, refresh tokens may expire; use the appropriate published/verified consent setup for ongoing sending.

## 4. Add Cloudflare Pages secrets

Cloudflare → Workers & Pages → frostly → Settings → Variables and Secrets. Add these as **secrets** (except the URL and sender address, which may be ordinary variables):

| Name | Value |
| --- | --- |
| `FROSTLY_SUPABASE_URL` | `https://ipezhryryolmebgzploa.supabase.co` |
| `FROSTLY_SUPABASE_SERVICE_ROLE_KEY` | Supabase service-role key; secret only |
| `FROSTLY_GMAIL_CLIENT_ID` | Google OAuth client ID |
| `FROSTLY_GMAIL_CLIENT_SECRET` | Google OAuth client secret; secret |
| `FROSTLY_GMAIL_REFRESH_TOKEN` | Refresh token for the sender account; secret |
| `FROSTLY_GMAIL_SENDER` | Gmail address authorized by that OAuth client |

Add the variables to the **Production** environment (and Preview too only if you want newsletter sending there). Never put service-role keys, OAuth secrets, or refresh tokens in `app.js`, `admin-app.js`, or any committed file. Redeploy after saving Cloudflare variables.

## 5. Send a campaign

Sign in as a permitted administrator, open **Settings → Gmail newsletter**, enter a subject and message, then send. Each active subscriber receives an individual message with an unsubscribe link. The endpoint currently caps a single campaign at 50 active subscribers and reports sent and failed counts. Gmail account sending quotas still apply.

Unsubscribes are recorded in Supabase and excluded from later campaigns. The unsubscribe page asks the recipient to confirm before applying the change.

## Troubleshooting

- **Google button reports a redirect error:** add the production wildcard above to Supabase's URL allow-list and confirm its Google sign-in provider is configured.
- **Subscription fails:** make sure the migration ran successfully and the deployed `app.js` calls `newsletter_subscribe`.
- **Campaign says sender not configured:** check each Cloudflare variable name and environment, then redeploy.
- **Gmail authorization failed:** verify the Gmail API is enabled, refresh token belongs to the configured OAuth client, sender email matches the authorized account, and `gmail.send` scope was granted.
- **Some messages fail:** check Gmail quotas and campaign counts; retry only the failed recipients after reviewing the provider quota.
