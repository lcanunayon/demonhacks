const CACHE_NAME = 'pednav-v2';

// App shell files to cache on install
const PRECACHE_URLS = [
  './',
  './index.html',
  './manifest.json',
  './icons/icon-192.png',
  './icons/icon-512.png',
  './assets/pedway_graph.js',
  './assets/map.jpg',
  './assets/logo.png',
];

// Install: pre-cache the app shell
self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache => {
      // Cache what we can; icons may not exist yet so ignore failures
      return Promise.allSettled(
        PRECACHE_URLS.map(url => cache.add(url).catch(() => {}))
      );
    }).then(() => self.skipWaiting())
  );
});

// Activate: clean up old caches
self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(keys =>
      Promise.all(
        keys.filter(key => key !== CACHE_NAME).map(key => caches.delete(key))
      )
    ).then(() => self.clients.claim())
  );
});

// Fetch strategy:
//   HTML files      → network-first  (always get latest deploy, fall back to cache offline)
//   Assets/images   → cache-first    (stable files, fast load)
//   External (CDN)  → network-first, silent fallback
self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);
  if (event.request.method !== 'GET') return;

  // External requests — network only, silent failure
  if (url.origin !== self.location.origin) {
    event.respondWith(
      fetch(event.request).catch(() => new Response('', { status: 408 }))
    );
    return;
  }

  const isHTML = url.pathname.endsWith('.html') || url.pathname.endsWith('/') || url.pathname === '/';

  if (isHTML) {
    // Network-first: always try to fetch fresh HTML, fall back to cache when offline
    event.respondWith(
      fetch(event.request).then(response => {
        const clone = response.clone();
        caches.open(CACHE_NAME).then(cache => cache.put(event.request, clone));
        return response;
      }).catch(() => caches.match(event.request))
    );
  } else {
    // Cache-first: serve assets instantly, update cache in background
    event.respondWith(
      caches.match(event.request).then(cached => {
        const fetchAndCache = fetch(event.request).then(response => {
          if (response.status === 200) {
            const clone = response.clone();
            caches.open(CACHE_NAME).then(cache => cache.put(event.request, clone));
          }
          return response;
        });
        return cached || fetchAndCache;
      })
    );
  }
});
