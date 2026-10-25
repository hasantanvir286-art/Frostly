(() => {
  const config = window.FROSTLY_SUPABASE_CONFIG || {};
  const directFetch = window.fetch.bind(window);
  let supabaseOrigin = '';
  try { supabaseOrigin = new URL(config.url).origin; } catch {}

  window.FROSTLY_SUPABASE_FETCH = (input, init) => {
    const request = input instanceof Request ? new Request(input, init) : new Request(input, init);
    const url = new URL(request.url);
    if (url.origin !== supabaseOrigin || window.location.protocol !== 'https:') {
      return directFetch(request);
    }

    // Supabase Auth is designed for browser CORS requests. Keep its JSON
    // sign-in, sign-up, and token-refresh bodies out of the Pages proxy path.
    if (url.pathname.startsWith('/auth/v1/')) {
      return directFetch(request);
    }

    // This dashboard RPC only reads aggregate metrics. Keep it in the browser
    // so a transient Pages-to-Supabase egress failure cannot break the overview.
    if (request.method === 'POST' && url.pathname === '/rest/v1/rpc/admin_dashboard_metrics') {
      return directFetch(request);
    }

    const proxyUrl = new URL(`/api/supabase${url.pathname}${url.search}`, window.location.origin);
    if (request.method === 'GET' || request.method === 'HEAD') {
      return directFetch(new Request(proxyUrl, request)).then(response => {
        if ([404, 500, 502, 503].includes(response.status)) return directFetch(request);
        return response;
      }).catch(() => directFetch(request));
    }
    const isImageUpload = ['POST', 'PUT'].includes(request.method)
      && /^\/storage\/v1\/object\/(frostly-avatars|frostly-products|frostly-site-assets)\//.test(url.pathname);
    if (isImageUpload) {
      return directFetch(new Request(proxyUrl, request.clone())).then(response => {
        // The Storage service still enforces the bucket's MIME, size and RLS
        // rules. Retry direct when the Pages proxy rejects or cannot reach it.
        if ([415, 502, 503].includes(response.status)) return directFetch(request);
        return response;
      }).catch(() => directFetch(request));
    }
    return directFetch(new Request(proxyUrl, request));
  };

  window.frostlySupabaseAssetUrl = (value) => {
    if (!value || !supabaseOrigin || window.location.protocol !== 'https:') return value;
    try {
      const url = new URL(value, window.location.href);
      if (url.origin !== supabaseOrigin || !url.pathname.startsWith('/storage/v1/')) return value;
      // Public objects are already served by Supabase's CDN. Avoid routing
      // storefront <img> requests through the Pages API proxy.
      if (url.pathname.startsWith('/storage/v1/object/public/')) return value;
      return `${window.location.origin}/api/supabase${url.pathname}${url.search}${url.hash}`;
    } catch {
      return value;
    }
  };
})();
