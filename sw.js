/* Kirolorik · sw.js · v13 · 2026-10-31 · pantalla de «sin conexión» con explicación (posible bloqueo del operador); (v12: guarda también faq.html y legal.html para abrirlas sin red; (v11: espera de red de 1,5 s en vez de 4 s para que la app abra rápido con la web bloqueada; (v10: la portada, el CSS y los scripts quedan guardados al instalar y se sirven si falla la red (bloqueos de IPs en días de partido); cache v10) · cache v12) */

const CACHE = 'kirolorik-v12';

// Se guardan al instalar para poder abrir la app sin red
const PRECACHE = ['/', '/index.html', '/assets/css/style.css', '/assets/js/i18n.js', '/pages/faq.html', '/pages/legal.html'];

// Pantalla que se muestra si falla la red y la página pedida no está guardada
const OFFLINE_HTML = '<!DOCTYPE html><html lang="es"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Kirolorik</title></head>'
  + '<body style="margin:0;font-family:system-ui,sans-serif;background:#f4f6fa;color:#1a1f2e;display:flex;min-height:100vh;align-items:center;justify-content:center;text-align:center">'
  + '<div style="max-width:340px;padding:24px"><img src="/assets/img/logo.png" alt="Kirolorik" style="width:72px;height:72px;margin-bottom:12px">'
  + '<h1 style="font-size:20px;margin:0 0 8px">Sin conexión</h1>'
  + '<p style="font-size:14px;line-height:1.5;margin:0 0 12px">No se ha podido abrir esta página. Puede que tu operador esté bloqueando la web por los partidos. Prueba con una VPN o con WARP, o vuelve a intentarlo más tarde.</p>'
  + '<p style="font-size:13px;line-height:1.5;color:#667;margin:0 0 16px">Konexiorik ez. Agian zure operadoreak webgunea blokeatzen ari da partidengatik. Saiatu VPN batekin edo WARP-ekin.</p>'
  + '<a href="/" style="display:inline-block;background:#1a6bff;color:#fff;text-decoration:none;font-weight:700;font-size:14px;padding:10px 20px;border-radius:999px">Volver al inicio</a></div></body></html>';

const CACHE_FIRST = [
  '/manifest.json',
  '/assets/img/logo.png',
  '/assets/img/icon-192.png',
  '/assets/img/icon-512.png'
];

// Timeout para network-first: si la red no responde en 1,5 s, usa caché
function fetchWithTimeout(request, ms) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('timeout')), ms);
    fetch(request).then(res => { clearTimeout(timer); resolve(res); }, err => { clearTimeout(timer); reject(err); });
  });
}

self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE)
      .then(c => Promise.all(CACHE_FIRST.concat(PRECACHE).map(a =>
        c.add(new Request(a, {cache:'reload'})).catch(() => {})
      )))
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
  const isAsset = url.origin === self.location.origin && (url.pathname.endsWith('.css') || url.pathname.endsWith('.js'));

  if (isHtml || isAsset) {
    // NETWORK FIRST con timeout — páginas, CSS y JS propios: si la red falla o tarda, cae al caché
    e.respondWith(
      fetchWithTimeout(e.request, 1500)
        .then(res => {
          if (res.ok) {
            caches.open(CACHE).then(c => c.put(e.request, res.clone()));
          }
          return res;
        })
        .catch(() =>
          caches.match(e.request, {ignoreSearch: true})
            .then(r => r || (isAsset ? null : caches.match('/')))
            .then(r => r || (isAsset ? null : caches.match('/index.html')))
            .then(r => r || (isAsset ? new Response('', {status: 503}) : new Response(OFFLINE_HTML, {status: 503, headers: {'Content-Type': 'text/html; charset=utf-8'}})))
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
  // Fuentes — sin interceptar, red directa
});
