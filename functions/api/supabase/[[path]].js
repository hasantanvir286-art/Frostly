const DEFAULT_SUPABASE_URL = 'https://ipezhryryolmebgzploa.supabase.co';
const ALLOWED_PREFIXES = ['/rest/v1', '/storage/v1'];
const MAX_REQUEST_BYTES = 6 * 1024 * 1024;
const IMAGE_BUCKET_LIMITS = new Map([
  ['frostly-avatars', 3 * 1024 * 1024],
  ['frostly-products', 5 * 1024 * 1024],
  ['frostly-site-assets', 5 * 1024 * 1024],
]);

function secureHeaders(headers) {
  headers.set('Cache-Control', 'private, no-store');
  headers.set('X-Content-Type-Options', 'nosniff');
  headers.set('Referrer-Policy', 'strict-origin-when-cross-origin');
  headers.set('X-Frame-Options', 'DENY');
  headers.set('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
  return headers;
}

async function readBodyLimited(request, limit) {
  if (!request.body) return new Uint8Array();
  const reader = request.body.getReader();
  const chunks = [];
  let total = 0;
  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      total += value.byteLength;
      if (total > limit) {
        await reader.cancel();
        return null;
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const body = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) { body.set(chunk, offset); offset += chunk.byteLength; }
  return body;
}

function imageTypeMatches(body, contentType) {
  const starts = (...bytes) => bytes.every((byte, index) => body[index] === byte);
  if (contentType === 'image/jpeg') return starts(0xff, 0xd8, 0xff);
  if (contentType === 'image/png') return starts(0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a);
  if (contentType === 'image/webp') return starts(0x52, 0x49, 0x46, 0x46) && body.length >= 12 && body[8] === 0x57 && body[9] === 0x45 && body[10] === 0x42 && body[11] === 0x50;
  return false;
}

export async function onRequest({ request, env }) {
  const incoming = new URL(request.url);
  const prefix = '/api/supabase';
  const path = incoming.pathname.slice(prefix.length) || '/';

  const response = (body, status) => new Response(body, {
    status,
    headers: secureHeaders(new Headers({ 'Content-Type': 'text/plain; charset=utf-8' })),
  });

  if (!ALLOWED_PREFIXES.some((allowed) => path === allowed || path.startsWith(`${allowed}/`))) {
    return response('Not found', 404);
  }

  if (!['GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE'].includes(request.method)) return response('Method not allowed', 405);
  const origin = request.headers.get('Origin');
  if (origin && origin !== incoming.origin) return response('Cross-origin request denied', 403);
  if (request.headers.get('Sec-Fetch-Site') === 'cross-site') return response('Cross-site request denied', 403);

  let upstream;
  try {
    upstream = new URL(env.FROSTLY_SUPABASE_URL || DEFAULT_SUPABASE_URL);
  } catch {
    return response('Supabase proxy is not configured', 503);
  }
  if (upstream.protocol !== 'https:' || upstream.hostname !== new URL(DEFAULT_SUPABASE_URL).hostname || upstream.username || upstream.password || upstream.port) {
    return response('Supabase proxy upstream is not allowed', 500);
  }

  const target = new URL(`${path}${incoming.search}`, upstream.origin);
  const headers = new Headers(request.headers);
  headers.delete('host');
  headers.delete('content-length');
  headers.delete('cookie');
  headers.delete('origin');
  headers.delete('referer');
  const requestInit = {
    method: request.method,
    headers,
    redirect: 'error',
  };
  if (request.method !== 'GET' && request.method !== 'HEAD') {
    const declaredLength = Number(request.headers.get('content-length') || 0);
    if (declaredLength > MAX_REQUEST_BYTES) return response('Request body too large', 413);
    const imageBucket = path.match(/^\/storage\/v1\/object\/(frostly-avatars|frostly-products|frostly-site-assets)\//)?.[1];
    const maxBytes = imageBucket ? IMAGE_BUCKET_LIMITS.get(imageBucket) : MAX_REQUEST_BYTES;
    const body = await readBodyLimited(request, maxBytes);
    if (!body) return response('Request body too large', 413);
    if (imageBucket && ['POST', 'PUT'].includes(request.method)) {
      const contentType = (headers.get('content-type') || '').split(';', 1)[0].trim().toLowerCase();
      if (!imageTypeMatches(body, contentType)) return response('Only valid JPEG, PNG, and WebP image uploads are accepted', 415);
    }
    requestInit.body = body;
  }

  try {
    const upstreamResponse = await fetch(new Request(target, requestInit));
    const responseHeaders = secureHeaders(new Headers(upstreamResponse.headers));
    responseHeaders.delete('Set-Cookie');
    return new Response(upstreamResponse.body, {
      status: upstreamResponse.status,
      statusText: upstreamResponse.statusText,
      headers: responseHeaders,
    });
  } catch {
    return response('Supabase is temporarily unavailable', 502);
  }
}
