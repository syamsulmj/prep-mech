// PWA wiring: register the Service Worker and reflect connectivity in the offline banner.
// Both parts are side-effect-guarded so it is safe to call initPwa() on every page.
export function initPwa() {
  registerServiceWorker()
  initOfflineBanner()
}

function registerServiceWorker() {
  if (!("serviceWorker" in navigator)) return
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/sw.js").catch((err) => {
      console.error("Service worker registration failed:", err)
    })
  })
}

function initOfflineBanner() {
  const banner = document.getElementById("offline-banner")
  if (!banner) return
  // Show the banner whenever the browser reports it is offline.
  const sync = () => banner.classList.toggle("hidden", navigator.onLine)
  window.addEventListener("online", sync)
  window.addEventListener("offline", sync)
  sync()
}
