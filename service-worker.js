const CACHE_NAME = 'nawrah-shell-v1';
const SHELL_URLS = [
  '/',
  '/index.html',
  '/console-a84d8903f59b4d358c8cc927633a11f6.html',
  '/styles.css?v=20261104-android-pwa',
  '/app.js?v=20261104-supabase-retry',
  '/admin-app.js?v=20261104-supabase-retry',
  '/supabase-config.js',
  '/supabase-proxy.js?v=20261104-guarded-write-fallback',
  '/manifest.webmanifest',
  '/pwa-install.js?v=20261104-android-pwa',
  '/icons/nawrah-192.png',
  '/icons/nawrah-512.png'
];

self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(CACHE_NAME).then((cache) => cache.addAll(SHELL_URLS)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (event) => {
  event.waitUntil(caches.keys().then((keys) => Promise.all(keys.filter((key) => key.startsWith('nawrah-shell-') && key !== CACHE_NAME).map((key) => caches.delete(key)))).then(() => self.clients.claim()));
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  const url = new URL(request.url);
  if (request.method !== 'GET' || url.origin !== self.location.origin || url.pathname.startsWith('/api/')) return;

  if (request.mode === 'navigate') {
    event.respondWith(fetch(request).then((response) => {
      if (response.ok) caches.open(CACHE_NAME).then((cache) => cache.put(request, response.clone()));
      return response;
    }).catch(async () => (await caches.match(request)) || (await caches.match('/index.html'))));
    return;
  }

  // Network-first keeps app updates current, with a cached shell asset when offline.
  event.respondWith(fetch(request).then((response) => {
    if (response.ok && response.type === 'basic') caches.open(CACHE_NAME).then((cache) => cache.put(request, response.clone()));
    return response;
  }).catch(async () => (await caches.match(request)) || Response.error()));
});
