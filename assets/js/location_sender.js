// Shopper-side GPS streamer. While the on_delivery job page is open, push the
// device location to the `location:<id>` channel (throttled ~10s).
import {getSocket} from "./socket"

const THROTTLE_MS = 10000

export function initLocationSender() {
  const el = document.getElementById("location-sender")
  if (!el) return
  const socket = getSocket()
  if (!socket || !navigator.geolocation) return

  const channel = socket.channel(`location:${el.dataset.orderId}`, {})
  channel.join()

  let lastSent = 0
  const watchId = navigator.geolocation.watchPosition(
    (pos) => {
      const now = Date.now()
      if (now - lastSent < THROTTLE_MS) return
      lastSent = now
      channel.push("loc", {lat: pos.coords.latitude, lng: pos.coords.longitude})
    },
    () => {}, // ignore transient geolocation errors
    {enableHighAccuracy: true, maximumAge: THROTTLE_MS, timeout: 20000}
  )

  window.addEventListener("beforeunload", () => navigator.geolocation.clearWatch(watchId))
}
