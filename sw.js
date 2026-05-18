/* Kirolorik · sw.js · v6 · 2026-05-17 */

const CACHE = 'kirolorik-v6';

// Solo se cachean agresivamente los assets estáticos que casi nunca cambian
const CACHE_FIRST = [
  '/manifest.json',
  '/assets/img/logo.png',
  '/assets/img/icon-192.png',
  '/assets/img/icon-512.png'
];

self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE)
      .then(c => c.addAll(CACHE_FIRST.map(a => new Request(a, {cache:'reload'}))))
      .catch(() => {})
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
  if (
    e.request.url.includes('supabase.co') ||
    e.request.url.includes('googleapis.com') ||
    e.request.url.includes('google.com/maps') ||
    e.request.method !== 'GET'
  ) return;

  const url = new URL(e.request.url);
  const isHtml = url.pathname.endsWith('.html') || url.pathname === '/' || url.pathname === '';
  const isCacheFirst = CACHE_FIRST.some(p => url.pathname === p);

  if (isHtml) {
    // NETWORK FIRST — todos los HTML siempre frescos
    e.respondWith(
      fetch(e.request)
        .then(res => {
          if (res.ok) {
            caches.open(CACHE).then(c => c.put(e.request, res.clone()));
          }
          return res;
        })
        .catch(() => caches.match(e.request).then(r => r || caches.match('/index.html')))
    );
  } else if (isCacheFirst) {
    // CACHE FIRST — imágenes y manifest
    e.respondWith(
      caches.match(e.request).then(cached => {
        if (cached) return cached;
        return fetch(e.request).then(res => {
          if (res.ok) caches.open(CACHE).then(c => c.put(e.request, res.clone()));
          return res;
        });
      })
    );
  }
  // El resto (CSS, JS, fuentes) — sin interceptar, van directo a la red
});
