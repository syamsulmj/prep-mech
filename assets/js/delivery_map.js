// Customer-side live delivery map. Renders a Leaflet map + a marker that follows
// the shopper's GPS pushes on the `location:<id>` channel. Leaflet (window.L) is
// loaded by the tracking page; we never touch `L` unless it is present.
import {getSocket} from "./socket"

let started = false
let map = null
let marker = null
let channel = null
let lastUpdatedAt = null
let staleTimer = null

const DEFAULT_CENTER = [3.139, 101.6869] // Kuala Lumpur — replaced on first fix
const STALE_AFTER_MS = 30000

function markerIcon() {
  return window.L.divIcon({
    className: "",
    html:
      '<div style="width:16px;height:16px;background:#FD4F00;border:2px solid #fff;' +
      'border-radius:50%;box-shadow:0 0 0 2px rgba(0,0,0,.35)"></div>',
    iconSize: [16, 16],
    iconAnchor: [8, 8],
  })
}

function place(loc) {
  if (!loc || typeof loc.lat !== "number" || typeof loc.lng !== "number") return
  const latlng = [loc.lat, loc.lng]
  if (!marker) {
    marker = window.L.marker(latlng, {icon: markerIcon()}).addTo(map)
    map.setView(latlng, 15)
  } else {
    marker.setLatLng(latlng)
    map.panTo(latlng)
  }
  if (loc.updated_at) lastUpdatedAt = loc.updated_at * 1000
  renderStale()
}

function renderStale() {
  const el = document.getElementById("delivery-map-stale")
  if (!el) return
  if (lastUpdatedAt && Date.now() - lastUpdatedAt > STALE_AFTER_MS) {
    const mins = Math.max(1, Math.round((Date.now() - lastUpdatedAt) / 60000))
    el.textContent = `Last seen ${mins} min ago`
    el.classList.remove("hidden")
  } else {
    el.classList.add("hidden")
  }
}

function start() {
  if (started) return
  const el = document.getElementById("delivery-map")
  if (!el || !window.L) return
  const socket = getSocket()
  if (!socket) return

  started = true
  map = window.L.map(el).setView(DEFAULT_CENTER, 12)
  window.L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
    maxZoom: 19,
    attribution: "© OpenStreetMap contributors",
  }).addTo(map)

  channel = socket.channel(`location:${el.dataset.orderId}`, {})
  channel.join().receive("ok", (reply) => place(reply.location))
  channel.on("loc", place)

  staleTimer = setInterval(renderStale, 10000)
}

// Tear down when the map leaves the page (e.g. order → delivered swaps the div out).
function teardown() {
  if (!started) return
  if (staleTimer) clearInterval(staleTimer)
  if (channel) channel.leave()
  if (map) map.remove()
  started = false
  map = null
  marker = null
  channel = null
  lastUpdatedAt = null
  staleTimer = null
}

function sync() {
  if (document.getElementById("delivery-map")) {
    start()
  } else {
    teardown()
  }
}

export function initDeliveryMap() {
  // The map container can arrive/leave on a live-region swap (order → on_delivery
  // → delivered), so sync on load AND after each swap. Both start() and teardown()
  // are idempotent.
  sync()
  document.addEventListener("live-region:updated", sync)
}
