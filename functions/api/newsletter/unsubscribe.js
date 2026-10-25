const html = (body, status = 200) => new Response(body, {
  status,
  headers: { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store', 'x-content-type-options': 'nosniff', 'content-security-policy': "default-src 'none'; style-src 'unsafe-inline'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'" }
});

export async function onRequestGet({ request }) {
  const token = new URL(request.url).searchParams.get('token') || '';
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(token)) {
    return html('<main><h1>Invalid unsubscribe link</h1><p>Please contact Frostly for help.</p></main>', 400);
  }
  const action = new URL(request.url);
  action.search = new URLSearchParams({ token });
  return html(`<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Unsubscribe · Frostly</title><main style="font:16px/1.6 Arial,sans-serif;max-width:480px;margin:12vh auto;padding:24px;color:#102a43"><h1>Unsubscribe from Frostly emails</h1><p>Confirm below to stop receiving promotional emails from Frostly.</p><form method="post" action="${action.pathname + action.search}"><button style="padding:12px 18px;border:0;border-radius:8px;background:#087f6a;color:white;font-weight:700">Unsubscribe</button></form></main>`);
}

export async function onRequestPost({ request, env }) {
  const origin = request.headers.get('origin');
  if (origin && origin !== new URL(request.url).origin) return html('<h1>Request denied</h1>', 403);
  if (!env.FROSTLY_SUPABASE_URL || !env.FROSTLY_SUPABASE_SERVICE_ROLE_KEY) return html('<h1>Unsubscribe is temporarily unavailable</h1><p>Please contact Frostly for help.</p>', 503);
  const token = new URL(request.url).searchParams.get('token') || '';
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(token)) return html('<h1>Invalid unsubscribe link</h1>', 400);
  try {
    const base = env.FROSTLY_SUPABASE_URL.replace(/\/$/, '');
    const url = new URL(`${base}/rest/v1/newsletter_subscriptions`);
    url.search = new URLSearchParams({ unsubscribe_token: `eq.${token}` });
    const key = env.FROSTLY_SUPABASE_SERVICE_ROLE_KEY;
    const response = await fetch(url, { method: 'PATCH', headers: { apikey: key, authorization: `Bearer ${key}`, 'content-type': 'application/json', prefer: 'return=representation' }, body: JSON.stringify({ unsubscribed_at: new Date().toISOString() }) });
    if (!response.ok) throw new Error('unsubscribe request failed');
    const updated = await response.json();
    if (!updated.length) return html('<h1>This link is invalid or was already used.</h1>', 404);
    return html('<!doctype html><meta charset="utf-8"><title>Unsubscribed · Frostly</title><main style="font:16px/1.6 Arial,sans-serif;max-width:480px;margin:12vh auto;padding:24px;color:#102a43"><h1>You are unsubscribed</h1><p>You will no longer receive Frostly promotional emails at this address.</p></main>');
  } catch {
    return html('<h1>Unsubscribe is temporarily unavailable</h1><p>Please try again later or contact Frostly.</p>', 502);
  }
}
