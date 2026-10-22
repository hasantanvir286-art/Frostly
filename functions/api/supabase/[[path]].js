const DEFAULT_SUPABASE_URL = 'https://ipezhryryolmebgzploa.supabase.co';
const ALLOWED_PREFIXES = ['/auth/v1', '/rest/v1', '/storage/v1', '/functions/v1', '/graphql/v1'];

export async function onRequest({ request, env }) {
  const incoming = new URL(request.url);
  const prefix = '/api/supabase';
  const path = incoming.pathname.slice(prefix.length) || '/';

  if (!ALLOWED_PREFIXES.some((allowed) => path === allowed || path.startsWith(`${allowed}/`))) {
    return new Response('Not found', { status: 404 });
  }

  let upstream;
  try {
    upstream = new URL(env.FROSTLY_SUPABASE_URL || DEFAULT_SUPABASE_URL);
  } catch {
    return new Response('Supabase proxy is not configured', { status: 503 });
  }
  if (upstream.protocol !== 'https:') {
    return new Response('Supabase proxy requires an HTTPS upstream', { status: 500 });
  }

  const target = new URL(`${path}${incoming.search}`, upstream.origin);
  const forwardRequest = new Request(target, request);

  try {
    const response = await fetch(forwardRequest);
    const headers = new Headers(response.headers);
    headers.set('Cache-Control', 'private, no-store');
    return new Response(response.body, {
      status: response.status,
      statusText: response.statusText,
      headers,
    });
  } catch {
    return new Response('Supabase is temporarily unavailable', {
      status: 502,
      headers: { 'Cache-Control': 'no-store' },
    });
  }
}
