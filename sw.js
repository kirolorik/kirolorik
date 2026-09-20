/* Kirolorik · sw.js · v8 · 2026-09-20 */

const CACHE = 'kirolorik-v8';

const CACHE_FIRST = [
  '/manifest.json',
  '/assets/img/logo.png',
  '/assets/img/icon-192.png',
  '/assets/img/icon-512.png'
];

// Timeout para network-first: si la red no responde en 4s, usa caché
function fetchWithTimeout(request, ms) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('timeout')), ms);
    fetch(request).then(res => { clearTimeout(timer); resolve(res); }, err => { clearTimeout(timer); reject(err); });
  });
}

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
    // NETWORK FIRST con timeout — si la red falla o tarda, cae al caché
    e.respondWith(
      fetchWithTimeout(e.request, 4000)
        .then(res => {
          if (res.ok) {
            caches.open(CACHE).then(c => c.put(e.request, res.clone()));
          }
          return res;
        })
        .catch(() =>
          caches.match(e.request)
            .then(r => r || caches.match('/index.html'))
            .then(r => r || new Response('Sin conexión', {status: 503, headers: {'Content-Type': 'text/plain'}}))
        )
    );
  } else if (isCacheFirst) {
    // CACHE FIRST — imágenes y manifest
    e.respondWith(
      caches.match(e.request).then(cached => {
        if (cached) return cached;
        return fetch(e.request).then(res => {
          if (res.ok) caches.open(CACHE).then(c => c.put(e.request, res.clone()));
          return res;
        }).catch(() => new Response('', {status: 503}));
      })
    );
  }
  // CSS, JS, fuentes — sin interceptar, red directa
});
