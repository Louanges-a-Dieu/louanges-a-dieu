// Service worker du mode « ordinateur seul » (Phase 8.4) : la console de
// projection et l'écran projeté restent disponibles sans Internet (Q-08).
// Seules ces pages et leurs ressources statiques sont mises en cache ; les
// pages de programmes partagés (privées, sans cache) ne le sont jamais.
const CACHE = 'lad-projection-v1';
const PRECACHE = [
  '/projection',
  '/projection-ecran/screen.html',
  '/projection-ecran/screen.css',
  '/projection-ecran/screen.js',
  '/projection-ecran/tokens.css',
  '/projection-ecran/fonts/cormorant.ttf',
  '/projection-ecran/fonts/literata.ttf',
  '/projection-ecran/fonts/literata-italic.ttf',
  '/manifest.webmanifest',
  '/icons/icon-192.png',
  '/icons/icon-512.png',
];

function handled(url) {
  if (url.origin !== self.location.origin) return false;
  const p = url.pathname;
  return (
    p === '/projection' ||
    p.startsWith('/projection-ecran/') ||
    p.startsWith('/_next/static/') ||
    p.startsWith('/icons/') ||
    p === '/manifest.webmanifest'
  );
}

// Fichiers dont l'adresse change à chaque version : le cache suffit.
function immutable(url) {
  return (
    url.pathname.startsWith('/_next/static/') ||
    url.pathname.startsWith('/projection-ecran/fonts/') ||
    url.pathname.startsWith('/icons/')
  );
}

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches
      .open(CACHE)
      .then((cache) => cache.addAll(PRECACHE))
      .then(() => self.skipWaiting()),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim()),
  );
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  if (!handled(url)) return;
  // Requêtes de données de Next (navigation interne) : jamais servies depuis le cache.
  if (url.searchParams.has('_rsc') || request.headers.get('RSC')) return;

  if (immutable(url)) {
    event.respondWith(
      caches.match(request).then(
        (hit) =>
          hit ||
          fetch(request).then((response) => {
            if (response.ok) {
              const copy = response.clone();
              void caches.open(CACHE).then((cache) => cache.put(request, copy));
            }
            return response;
          }),
      ),
    );
    return;
  }

  // Le reste : réseau d'abord (version à jour), cache si hors ligne.
  event.respondWith(
    fetch(request)
      .then((response) => {
        if (response.ok) {
          const copy = response.clone();
          void caches.open(CACHE).then((cache) => cache.put(url.pathname, copy));
        }
        return response;
      })
      .catch(() =>
        caches.match(url.pathname, { ignoreSearch: true }).then((hit) => hit || Response.error()),
      ),
  );
});

// La console envoie les ressources qu'elle a chargées avant l'activation du
// service worker : elles sont mises en cache pour l'usage hors ligne.
self.addEventListener('message', (event) => {
  if (!event.data || event.data.type !== 'warm') return;
  const urls = (event.data.urls || [])
    .map((u) => new URL(u, self.location.origin))
    .filter(handled)
    .map((u) => (immutable(u) ? u.href : u.pathname));
  event.waitUntil(
    caches
      .open(CACHE)
      .then((cache) =>
        Promise.all(
          [...new Set(urls)].map((u) =>
            cache.match(u).then((hit) => hit || cache.add(u).catch(() => undefined)),
          ),
        ),
      )
      .then(() => event.source && event.source.postMessage({ type: 'warmed' })),
  );
});
