(() => {
  const article = document.querySelector('[data-policy-page]');
  const config = window.FROSTLY_SUPABASE_CONFIG || {};
  if (!article || !window.supabase || !config.url || !config.anonKey) return;

  const client = window.supabase.createClient(config.url, config.anonKey, {
    global: { fetch: window.FROSTLY_SUPABASE_FETCH || window.fetch.bind(window) }
  });

  async function loadPolicyCopy() {
    try {
      const { data, error } = await client.from('site_settings')
        .select('policy_pages')
        .eq('id', 'main')
        .maybeSingle();
      if (error) throw error;

      const page = data?.policy_pages?.[article.dataset.policyPage];
      if (!page || typeof page !== 'object') return;

      const title = article.querySelector('h1');
      const intro = article.querySelector('.policy-updated');
      const backLink = article.querySelector('.policy-back');
      if (page.title && title) title.textContent = page.title;
      if (page.intro && intro) intro.textContent = page.intro;
      if (!page.body?.trim()) return;

      for (const child of [...article.children]) {
        if (child !== title && child !== intro && child !== backLink) child.remove();
      }
      const blocks = page.body.trim().split(/\n\s*\n/).map(value => value.trim()).filter(Boolean);
      for (const block of blocks) {
        const paragraph = document.createElement('p');
        paragraph.textContent = block;
        article.insertBefore(paragraph, backLink || null);
      }
    } catch (error) {
      console.warn('Could not load editable policy copy:', error.message || error);
    }
  }

  loadPolicyCopy();
})();
