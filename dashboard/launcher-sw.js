// PC 런처 Service Worker
const CACHE = 'pc-launcher-v1';

self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE).then(c => c.add('/dtslib-apk-lab/pc-launcher.html'))
  );
  self.skipWaiting();
});

self.addEventListener('activate', e => {
  e.waitUntil(clients.claim());
});

self.addEventListener('fetch', e => {
  // PC 서버 요청(localhost:7777)은 캐시 안 거침
  if (e.request.url.includes('localhost:7777')) return;
  e.respondWith(
    caches.match(e.request).then(r => r || fetch(e.request))
  );
});
