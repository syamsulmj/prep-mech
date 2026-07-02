// PrepMech Service Worker — Phase 5 (offline READING: app shell + visited pages).
// Offline writes (checking off items, advancing status) are Phase 6 and are NOT handled here;
// non-GET requests pass straight through and fail normally when offline.

const STATIC_CACHE = "prepmech-static-v2"
const PAGES_CACHE = "prepmech-pages-v2"
const CURRENT_CACHES = [STATIC_CACHE, PAGES_CACHE]

// Stable-named files precached at install. Fingerprinted assets (/assets/app-<hash>.js) are
// deliberately NOT listed here — their names change per deploy, so they are runtime cache-first
// (see the fetch handler) instead of precached.
const PRECACHE_URLS = [
  "/offline.html",
  "/manifest.json",
  "/images/icon-192.png",
  "/images/icon-512.png",
]

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches
      .open(STATIC_CACHE)
      .then((cache) => cache.addAll(PRECACHE_URLS))
      .then(() => self.skipWaiting())
  )
})

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(
          keys.filter((key) => !CURRENT_CACHES.includes(key)).map((key) => caches.delete(key))
        )
      )
      .then(() => self.clients.claim())
  )
})

self.addEventListener("fetch", (event) => {
  const {request} = event

  // Mutations & other non-GET requests: straight to the network (Phase 6 owns offline writes).
  if (request.method !== "GET") return

  const url = new URL(request.url)

  // 1. HTML navigations — network-first, then the cached copy of THIS page, then offline.html.
  //    TRADEOFF (Phase 5, single-user assumption): cached HTML is authenticated content keyed
  //    only by URL, and this cache is not cleared on logout. On a SHARED device, user B could see
  //    user A's last-cached page while offline. Accepted for the offline-read demo; a hardening
  //    step (clear PAGES_CACHE on logout, or skip caching authenticated routes) is future work.
  if (request.mode === "navigate") {
    event.respondWith(
      fetch(request)
        .then((response) => {
          const copy = response.clone()
          event.waitUntil(caches.open(PAGES_CACHE).then((cache) => cache.put(request, copy)))
          return response
        })
        .catch(() =>
          caches.match(request).then((cached) => cached || caches.match("/offline.html"))
        )
    )
    return
  }

  // 2. Same-origin static assets — STALE-WHILE-REVALIDATE. Serve the cached copy instantly (fast,
  //    offline-capable), but always refetch in the background and update the cache. This keeps a
  //    stable-named dev bundle (/assets/app.js) from going stale — a changed asset self-heals on the
  //    next load — while a fingerprinted prod bundle just re-validates the same immutable file.
  if (url.origin === self.location.origin && /^\/(assets|fonts|images)\//.test(url.pathname)) {
    event.respondWith(
      caches.open(STATIC_CACHE).then((cache) =>
        cache.match(request).then((cached) => {
          const networkFetch = fetch(request)
            .then((response) => {
              cache.put(request, response.clone())
              return response
            })
            .catch(() => cached) // offline: fall back to whatever we have cached
          // Keep the SW alive for the background update; serve cache now if we have it.
          event.waitUntil(networkFetch)
          return cached || networkFetch
        })
      )
    )
    return
  }

  // 3. Everything else (e.g. live_region's HTML re-fetch of window.location.href) — passthrough.
  //    We intentionally do NOT serve these from cache: the caller wants fresh HTML or nothing,
  //    and it has its own try/catch for the offline case.
})
