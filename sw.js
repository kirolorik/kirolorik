const CACHE = 'kirolorik-v1';
const ASSETS = [
  './', // Mejor usar rutas relativas
  './index.html',
  './manifest.json',
  './icon-192.png',
  './icon-512.png'
];

self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE).then(c => {
      console.log('SW: Cacheando assets críticos');
      return c.addAll(ASSETS);
    })
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
  // 1. Ignorar peticiones que no sean GET (como POST de formularios)
  // 2. Solo manejar esquemas http o https
  if (e.request.method !== 'GET' || !e.request.url.startsWith('http')) return;

  e.respondWith(
    caches.match(e.request).then(cached => {
      const networkFetch = fetch(e.request).then(res => {
        // Solo cacheamos si la respuesta es válida (status 200)
        if (res && res.status === 200 && res.type === 'basic') {
          const copy = res.clone();
          caches.open(CACHE).then(c => c.put(e.request, copy));
        }
        return res;
      }).catch(() => {
        // Si falla la red, buscamos en el caché
        return caches.match(e.request) || caches.match('./index.html');
      });

      return cached || networkFetch;
    })
  );
});
