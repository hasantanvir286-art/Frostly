(() => {
  const config = window.FROSTLY_SUPABASE_CONFIG || {};
  const directFetch = window.fetch.bind(window);
  let supabaseOrigin = '';
  try { supabaseOrigin = new URL(config.url).origin; } catch {}

  window.FROSTLY_SUPABASE_FETCH = (input, init) => {
    const request = input instanceof Request ? new Request(input, init) : new Request(input, init);
    // Supabase's browser API is protected by its public anon key and database
    // RLS. Call it directly so a Pages-to-Supabase proxy outage cannot break
    // profile, dashboard, checkout, or storage operations.
    return directFetch(request);
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
