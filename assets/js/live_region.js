import {getSocket} from "./socket"

// Customer realtime: when the order(s) this page watches change, re-fetch the
// page and swap #live-region. Reuses the server-rendered HTML — no markup in JS.
//
// A "poor man's LiveView": rather than re-derive the stepper / status / checklist
// in JavaScript (a second source of truth), we let the server render it and just
// splice the fresh region in. The channel push carries no data — it only says
// "something changed", and we re-pull the authoritative HTML.
export function initLiveRegion() {
  const region = document.getElementById("live-region")
  if (!region) return
  const topic = region.dataset.liveTopic
  const socket = getSocket()
  if (!topic || !socket) return

  const channel = socket.channel(topic, {})
  channel.join()
  channel.on("updated", async () => {
    try {
      const res = await fetch(window.location.href, {headers: {"x-requested-with": "fetch"}})
      if (!res.ok) return
      const doc = new DOMParser().parseFromString(await res.text(), "text/html")
      const fresh = doc.getElementById("live-region")
      const current = document.getElementById("live-region")
      if (fresh && current) current.replaceChildren(...fresh.childNodes)
    } catch (_e) {
      // transient fetch failure — the next event or a manual refresh recovers
    }
  })
}
