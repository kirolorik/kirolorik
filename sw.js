const CACHE = 'kirolorik-v3';
const ASSETS = [
  '/',
  '/index.html',
  '/style.css',
  '/i18n.js',
  '/manifest.json',
  '/icon-192.png',
  '/icon-512.png',
  '/logo.png'
];

self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE)
      .then(c => c.addAll(ASSETS.map(a => new Request(a, {cache: 'reload'}))))
      .catch(() => {}) // No bloquear instalación si falla algún asset
  );
  self.skipWaiting();
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener('fetch', e => {
  // Nunca interceptar Supabase, APIs externas, ni peticiones POST
  if (
    e.request.url.includes('supabase.co') ||
    e.request.url.includes('googleapis.com') ||
    e.request.url.includes('google.com/maps') ||
    e.request.url.includes('unsplash.com') ||
    e.request.method !== 'GET'
  ) return;

  e.respondWith(
    caches.match(e.request)
      .then(cached => {
        if (cached) return cached;
        return fetch(e.request).then(res => {
          if (res.ok) {
            const copy = res.clone();
            caches.open(CACHE).then(c => c.put(e.request, copy));
          }
          return res;
        });
      })
      .catch(() => caches.match('/index.html'))
  );
});
