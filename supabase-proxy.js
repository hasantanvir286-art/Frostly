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
    // These narrow RPCs enforce ownership/role checks and validation in
    // PostgreSQL. Retry them directly against Supabase only when the Pages
    // proxy itself fails, so orders and account actions survive proxy outages.
    const guardedWriteRpc = request.method === 'POST' &&
      /^\/rest\/v1\/rpc\/(place_store_order|create_cod_order|customer_cancel_order|admin_set_order_status|admin_adjust_inventory|superadmin_delete_customer|superadmin_delete_staff)$/.test(target.pathname);
    // Category mutations are protected by the catalog-manager RLS policy. Allow a
    // narrowly scoped direct retry only when the Pages proxy returns its
    // explicit upstream 502; do not retry them on arbitrary proxy/network errors.
    const adminCategoryWrite = ['POST', 'PATCH'].includes(request.method) &&
      target.pathname === '/rest/v1/categories';
    // Storefront configuration writes are limited to this single table and are
    // authorized by site_settings_admin_insert/update RLS policies. A direct
    // retry is permitted only after the Pages proxy returned an explicit 502
    // (the proxy's IP/rate guard has already accepted that request).
    const adminSettingsWrite = ['POST', 'PATCH'].includes(request.method) &&
      target.pathname === '/rest/v1/site_settings';
    // These exact customer-owned tables enforce user_id = auth.uid() through RLS.
    const customerWishlistWrite = ['POST', 'DELETE'].includes(request.method) &&
      target.pathname === '/rest/v1/product_wishlist';
    const customerStockAlertWrite = ['POST', 'PATCH'].includes(request.method) &&
      target.pathname === '/rest/v1/product_stock_alerts';
    // Product reviews are independently constrained by RLS to a delivered
    // order belonging to the signed-in customer.
    const verifiedReviewUpsert = request.method === 'POST' && target.pathname === '/rest/v1/product_reviews';
    const mayFallback = safeRead || safeRpc || verifiedReviewUpsert || guardedWriteRpc || adminCategoryWrite || adminSettingsWrite || customerWishlistWrite || customerStockAlertWrite;
    const fallbackRequest = mayFallback ? request.clone() : null;
    const proxyUrl = new URL(`/api/supabase${target.pathname}${target.search}`, window.location.origin);
    return directFetch(new Request(proxyUrl, request)).then((response) => {
      if (response.status === 502 && mayFallback) return directFetch(fallbackRequest);
      return response;
    }).catch((error) => {
      if (safeRead || safeRpc || verifiedReviewUpsert || guardedWriteRpc) return directFetch(fallbackRequest);
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
