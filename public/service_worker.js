// PriceTracker service worker.
//
// Minimum required so Chrome/Edge/Android consider the app installable: a
// registered SW with a "fetch" handler. We deliberately keep this thin —
// no aggressive caching of HTML or asset fingerprints — so the live app
// keeps behaving exactly like the network version, and users don't get
// stuck on stale UI after a deploy. The icon/manifest assets are cached
// so the install/splash screens are snappy on repeat visits.

const VERSION = "v1";
const STATIC_CACHE = `pricetracker-static-${VERSION}`;
const PRECACHE_URLS = [
  "/manifest.webmanifest",
  "/icon.svg",
  "/icon.png",
  "/favicon.svg"
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(STATIC_CACHE).then((cache) => cache.addAll(PRECACHE_URLS))
  );
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((k) => k.startsWith("pricetracker-") && k !== STATIC_CACHE)
          .map((k) => caches.delete(k))
      )
    )
  );
  self.clients.claim();
});

self.addEventListener("fetch", (event) => {
  const req = event.request;
  if (req.method !== "GET") return;

  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return;

  // Cache-first for the icon/manifest set we precached; network for everything
  // else so HTML, JSON, and fingerprinted assets stay fresh.
  if (PRECACHE_URLS.includes(url.pathname)) {
    event.respondWith(
      caches.match(req).then((cached) => cached || fetch(req))
    );
  }
});
