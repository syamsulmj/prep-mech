import {Socket} from "phoenix"

// A single authenticated socket per page, created lazily and shared across
// features. The token comes from a <meta> tag rendered only for logged-in
// users; without it we never connect (so unauthenticated pages stay quiet).
let socketSingleton = null

export function getSocket() {
  if (socketSingleton) return socketSingleton
  const token = document.querySelector("meta[name='user-token']")?.getAttribute("content")
  if (!token) return null
  socketSingleton = new Socket("/socket", {params: {token}})
  socketSingleton.connect()
  return socketSingleton
}
