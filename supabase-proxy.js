(() => {
  const config = window.FROSTLY_SUPABASE_CONFIG || {};
  const directFetch = window.fetch.bind(window);
  let supabaseOrigin = '';
  try { supabaseOrigin = new URL(config.url).origin; } catch {}

  window.FROSTLY_SUPABASE_FETCH = (input, init) => {
    const request = new Request(input, init);
    if (!supabaseOrigin || window.location.protocol !== 'https:') return directFetch(request);

    const target = new URL(request.url);
    const apiPath = target.pathname.startsWith('/rest/v1/') || target.pathname === '/rest/v1' ||
      target.pathname.startsWith('/storage/v1/') || target.pathname === '/storage/v1';
    if (target.origin !== supabaseOrigin || !apiPath) return directFetch(request);

    // Keep auth endpoints on Supabase, while routing database and storage
    // requests through the same-origin Pages Function for request validation,
    // upload size/type checks, and consistent security headers.
    const proxyUrl = new URL(`/api/supabase${target.pathname}${target.search}`, window.location.origin);
    return directFetch(new Request(proxyUrl, request)).then((response) => {
      // A Pages proxy outage must not blank the storefront or customer profile.
      // Fall back only for safe reads; all mutations stay behind proxy checks.
      if (response.status === 502 && ['GET', 'HEAD'].includes(request.method)) return directFetch(request);
      return response;
    });
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
