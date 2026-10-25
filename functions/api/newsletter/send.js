const json = (body, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' },
});

function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char]));
}

function encodeBase64(bytes) {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

function mimeMessage({ sender, subject, message, unsubscribeUrl }) {
  const boundary = `frostly_${crypto.randomUUID().replaceAll('-', '')}`;
  const subjectEncoded = encodeBase64(new TextEncoder().encode(subject));
  const safeMessage = escapeHtml(message).replace(/\r?\n/g, '<br>');
  const textBody = `${message}\n\nUnsubscribe: ${unsubscribeUrl}`;
  const htmlBody = `<div style="font:16px/1.6 Arial,sans-serif;color:#102a43;white-space:normal">${safeMessage}</div><p style="font:12px Arial,sans-serif;color:#627d98;margin-top:28px"><a href="${escapeHtml(unsubscribeUrl)}">Unsubscribe from Frostly emails</a></p>`;
  const textEncoded = encodeBase64(new TextEncoder().encode(textBody));
  const htmlEncoded = encodeBase64(new TextEncoder().encode(htmlBody));
  const raw = [
    `From: Frostly <${sender}>`,
    `Subject: =?UTF-8?B?${subjectEncoded}?=`,
    'MIME-Version: 1.0',
    'List-Unsubscribe: <' + unsubscribeUrl + '>',
    'List-Unsubscribe-Post: List-Unsubscribe=One-Click',
    `Content-Type: multipart/alternative; boundary="${boundary}"`, '',
    `--${boundary}`, 'Content-Type: text/plain; charset="UTF-8"', 'Content-Transfer-Encoding: base64', '', textEncoded,
    `--${boundary}`, 'Content-Type: text/html; charset="UTF-8"', 'Content-Transfer-Encoding: base64', '', htmlEncoded,
    `--${boundary}--`, ''
  ].join('\r\n');
  return encodeBase64(new TextEncoder().encode(raw)).replaceAll('+', '-').replaceAll('/', '_').replace(/=+$/, '');
}

export async function onRequestPost({ request, env }) {
  const origin = request.headers.get('origin');
  if (!origin || origin !== new URL(request.url).origin) return json({ error: 'Same-origin requests only.' }, 403);
  const authorization = request.headers.get('authorization') || '';
  if (!authorization.startsWith('Bearer ')) return json({ error: 'Sign in as an administrator to send a campaign.' }, 401);

  const required = ['FROSTLY_SUPABASE_URL', 'FROSTLY_SUPABASE_SERVICE_ROLE_KEY', 'FROSTLY_GMAIL_CLIENT_ID', 'FROSTLY_GMAIL_CLIENT_SECRET', 'FROSTLY_GMAIL_REFRESH_TOKEN', 'FROSTLY_GMAIL_SENDER'];
  const missing = required.filter(key => !env[key]);
  if (missing.length) return json({ error: 'Newsletter sender is not configured in Cloudflare secrets.' }, 503);

  let payload;
  try { payload = await request.json(); } catch { return json({ error: 'Request body must be valid JSON.' }, 400); }
  const subject = String(payload?.subject || '').trim();
  const message = String(payload?.message || '').trim();
  if (!subject || subject.length > 160 || /[\r\n]/.test(subject) || !message || message.length > 8000) {
    return json({ error: 'Enter a subject (up to 160 characters) and message (up to 8,000 characters).' }, 400);
  }

  const base = env.FROSTLY_SUPABASE_URL.replace(/\/$/, '');
  const serviceHeaders = { apikey: env.FROSTLY_SUPABASE_SERVICE_ROLE_KEY, authorization: `Bearer ${env.FROSTLY_SUPABASE_SERVICE_ROLE_KEY}` };
  try {
    const userResponse = await fetch(`${base}/auth/v1/user`, { headers: { apikey: env.FROSTLY_SUPABASE_SERVICE_ROLE_KEY, authorization } });
    if (!userResponse.ok) return json({ error: 'Your admin session expired. Sign in again.' }, 401);
    const user = await userResponse.json();
    const roleUrl = new URL(`${base}/rest/v1/profiles`);
    roleUrl.search = new URLSearchParams({ select: 'role', id: `eq.${user.id}`, limit: '1' });
    const roleResponse = await fetch(roleUrl, { headers: serviceHeaders });
    if (!roleResponse.ok) return json({ error: 'Could not verify administrator role.' }, 502);
    const [profile] = await roleResponse.json();
    if (!['superadmin', 'admin', 'settingsmanager'].includes(profile?.role)) return json({ error: 'Administrator access is required.' }, 403);

    const listUrl = new URL(`${base}/rest/v1/newsletter_subscriptions`);
    listUrl.search = new URLSearchParams({ select: 'email,unsubscribe_token', unsubscribed_at: 'is.null', order: 'created_at.asc', limit: '51' });
    const listResponse = await fetch(listUrl, { headers: serviceHeaders });
    if (!listResponse.ok) return json({ error: 'Could not load subscribers. Apply the newsletter migration first.' }, 502);
    const subscribers = await listResponse.json();
    if (subscribers.length > 50) return json({ error: 'There are more than 50 active subscribers. Send in smaller batches after limiting the audience.' }, 413);
    if (!subscribers.length) return json({ sent: 0, failed: 0, message: 'There are no active subscribers yet.' });

    const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST', headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ client_id: env.FROSTLY_GMAIL_CLIENT_ID, client_secret: env.FROSTLY_GMAIL_CLIENT_SECRET, refresh_token: env.FROSTLY_GMAIL_REFRESH_TOKEN, grant_type: 'refresh_token' })
    });
    const tokenData = await tokenResponse.json();
    if (!tokenResponse.ok || !tokenData.access_token) return json({ error: 'Gmail authorization failed. Check the Gmail OAuth Cloudflare secrets.' }, 502);

    let cursor = 0, sent = 0, failed = 0;
    const workers = Array.from({ length: Math.min(4, subscribers.length) }, async () => {
      while (cursor < subscribers.length) {
        const subscriber = subscribers[cursor++];
        const unsubscribeUrl = new URL('/api/newsletter/unsubscribe', request.url);
        unsubscribeUrl.searchParams.set('token', subscriber.unsubscribe_token);
        const raw = mimeMessage({ sender: env.FROSTLY_GMAIL_SENDER, subject, message, unsubscribeUrl: unsubscribeUrl.href });
        try {
          const response = await fetch('https://gmail.googleapis.com/gmail/v1/users/me/messages/send', {
            method: 'POST', headers: { authorization: `Bearer ${tokenData.access_token}`, 'content-type': 'application/json' },
            body: JSON.stringify({ raw })
          });
          if (response.ok) sent++; else failed++;
        } catch { failed++; }
      }
    });
    await Promise.all(workers);
    return json({ sent, failed, message: failed ? 'Some emails could not be sent; check the Gmail sending quota and retry.' : 'Campaign sent.' });
  } catch {
    return json({ error: 'Newsletter sending failed. Check the Supabase and Gmail configuration.' }, 502);
  }
}
