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

    const safeRead = ['GET', 'HEAD'].includes(request.method);
    const safeRpc = request.method === 'POST' &&
      /^\/rest\/v1\/rpc\/(admin_dashboard_metrics|superadmin_list_users)$/.test(target.pathname);
    // A product review upsert is independently constrained by RLS to a
    // delivered order belonging to the signed-in customer. Allow this one
    // operation to recover if Pages proxying fails; keep order/admin writes
    // on the validated proxy path.
    const verifiedReviewUpsert = request.method === 'POST' && target.pathname === '/rest/v1/product_reviews';
    const mayFallback = safeRead || safeRpc || verifiedReviewUpsert;
    const fallbackRequest = mayFallback ? request.clone() : null;
    const proxyUrl = new URL(`/api/supabase${target.pathname}${target.search}`, window.location.origin);
    return directFetch(new Request(proxyUrl, request)).then((response) => {
      if (response.status === 502 && mayFallback) return directFetch(fallbackRequest);
      return response;
    }).catch((error) => {
      if (mayFallback) return directFetch(fallbackRequest);
      throw error;
    });
  };

  window.frostlySupabaseAssetUrl = (value) => {
    if (!value || !supabaseOrigin || window.location.protocol !== 'https:') return value;
    try {
      const url = new URL(value, window.location.href);
      if (url.origin !== supabaseOrigin || !url.pathname.startsWith('/storage/v1/')) return value;
      if (url.pathname.startsWith('/storage/v1/object/public/')) return value;
      return `${window.location.origin}/api/supabase${url.pathname}${url.search}${url.hash}`;
    } catch { return value; }
  };
})();
