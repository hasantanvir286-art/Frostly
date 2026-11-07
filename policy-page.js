(() => {
  const article=document.querySelector('[data-policy-page]');
  const pageKey=article?.dataset.policyPage;
  const config=window.FROSTLY_SUPABASE_CONFIG||{};
  if(!article||!pageKey)return;
  let language='en';try{language=localStorage.getItem('frostly-language-v2')==='bn'?'bn':'en'}catch{}
  document.documentElement.lang=language;
  const copy=window.policyTranslations?.[language]?.[pageKey]||window.policyTranslations?.en?.[pageKey];
  const title=article.querySelector('h1'),intro=article.querySelector('.policy-updated'),back=article.querySelector('.policy-back');
  const contact=document.querySelector('[data-policy-contact]'),backLabel=document.querySelector('[data-policy-back]');
  if(contact)contact.textContent=window.policyTranslations?.[language]?.contact||'Contact';
  if(backLabel)backLabel.textContent=window.policyTranslations?.[language]?.back||'← Back to Nawrah Kitchen';
  function renderSections(page,overrides={}){
    if(!page)return;
    const selected={...page,...overrides};
    if(title)title.textContent=selected.title||page.title;
    if(intro)intro.textContent=selected.intro||page.intro;
    for(const node of [...article.children])if(node!==title&&node!==intro&&node!==back)node.remove();
    const customBody=String(selected.body||'').trim();
    if(customBody){for(const block of customBody.split(/\n\s*\n/).map(x=>x.trim()).filter(Boolean)){const p=document.createElement('p');p.textContent=block;article.insertBefore(p,back||null)}return}
    for(const [heading,text] of page.sections||[]){const h=document.createElement('h2');h.textContent=heading;article.insertBefore(h,back||null);if(text){const p=document.createElement('p');p.textContent=text;article.insertBefore(p,back||null)}}
  }
  renderSections(copy);
  if(!window.supabase||!config.url||!config.anonKey)return;
  const client=window.supabase.createClient(config.url,config.anonKey,{global:{fetch:window.FROSTLY_SUPABASE_FETCH||window.fetch.bind(window)}});
  async function loadDynamic(){
    try{
      const [{data:settings,error:settingsError},{data:zones,error:zonesError}]=await Promise.all([
        client.from('site_settings').select('policy_pages,page_builder').eq('id','main').maybeSingle(),
        pageKey==='delivery'?client.from('delivery_zones').select('area_name,delivery_fee_bdt').eq('is_active',true).order('area_name'):Promise.resolve({data:[],error:null})
      ]);
      if(settingsError)throw settingsError;
      if(zonesError)throw zonesError;
      const saved=settings?.policy_pages?.[pageKey]||{},localized=saved[language]||{};
      const custom={title:localized.title||saved[`title_${language}`]||(language==='en'?saved.title||'':''),intro:localized.intro||saved[`intro_${language}`]||(language==='en'?saved.intro||'':''),body:localized.body||saved[`body_${language}`]||(language==='en'?saved.body||'':'')};
      if(pageKey==='delivery'){
        const areas=zones||[],list=areas.map(zone=>`${zone.area_name}: ৳ ${Number(zone.delivery_fee_bdt).toLocaleString(language==='bn'?'bn-BD':'en-BD')}`).join(' · ');
        const operations=settings?.page_builder?.operations||{},eta=language==='bn'?(operations.delivery_eta_bn||operations.delivery_eta_en):(operations.delivery_eta_en||operations.delivery_eta_bn);
        const deliveryIntro=eta||copy.intro;
        renderSections({...copy,intro:deliveryIntro,sections:[[copy.sections[0][0],areas.length?list:(language==='bn'?'এই মুহূর্তে কোনো ডেলিভারি এলাকা চালু নেই।':'No delivery areas are currently available.'),],...copy.sections.slice(1)]},custom);
      }else renderSections(copy,custom);
    }catch(error){console.warn('Could not load editable policy content:',error?.message||error)}
  }
  loadDynamic();
})();
