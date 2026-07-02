// Progressive enhancement for the shopper's item Picked/Unavailable toggles.
// Online: the native POST-redirect-GET is left untouched (keeps the advance button fresh).
// Offline: intercept, optimistically restyle, and queue in the outbox; on reconnect, drain + reload.
import {queueItem, allItems, removeItem} from "./outbox"

function csrfToken() {
  return document.querySelector("meta[name='csrf-token']")?.getAttribute("content") || ""
}

function isItemForm(form) {
  const action = form.getAttribute("action") || ""
  return action.includes("/jobs/") && action.includes("/items/")
}

// Reflect the chosen status using the class strings the server stashed in data-class-* (DRY).
function restyle(form, status) {
  form.querySelectorAll("button[data-toggle]").forEach((btn) => {
    const active = btn.dataset.toggle === status
    btn.className = active ? btn.dataset.classActive : btn.dataset.classInactive
  })
}

function setQueuedBadge(form, visible) {
  const row = form.closest("[data-item-id]")
  const badge = row && row.querySelector("[data-queued-badge]")
  if (badge) badge.classList.toggle("hidden", !visible)
}

function postToggle(url, status) {
  return fetch(url, {
    method: "POST",
    headers: {
      "content-type": "application/x-www-form-urlencoded",
      "x-csrf-token": csrfToken(),
    },
    body: "status=" + encodeURIComponent(status),
    credentials: "same-origin",
    redirect: "follow",
  })
}

async function onSubmit(event) {
  const form = event.target
  if (!isItemForm(form)) return
  if (navigator.onLine) return // online: let the native POST-redirect-GET happen

  const status = event.submitter && event.submitter.value
  if (status !== "picked" && status !== "unavailable") return
  event.preventDefault()

  const url = form.getAttribute("action")
  restyle(form, status)
  await queueItem(url, status)
  setQueuedBadge(form, true)
}

async function drain() {
  try {
    const records = await allItems()
    if (records.length === 0) return
    let drained = 0
    for (const {url, status} of records) {
      try {
        const res = await postToggle(url, status)
        if (res.ok) {
          await removeItem(url)
          drained++
        }
        // non-ok (e.g. 4xx/5xx): leave the record queued for a later retry; try the next one.
      } catch (_e) {
        break // network failure (still offline) — retry on the next 'online' event
      }
    }
    if (drained > 0 && location.pathname.startsWith("/jobs/")) {
      location.reload() // reconcile with server truth (advance button, any rejected toggle)
    }
  } catch (_e) {
    // IndexedDB unavailable / open failure — nothing to drain; ignore.
  }
}

export function initJobItems() {
  // Delegated listener: safe on every page (no-ops unless the submit target is an item form).
  document.addEventListener("submit", onSubmit)
  window.addEventListener("online", drain)
  drain()
}
