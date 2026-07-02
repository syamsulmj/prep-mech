import {getSocket} from "./socket"

// Shopper pool: realtime add/remove of order cards + a quick-pickup modal.
// The pool subscribes to the "orders:pool" channel; when a customer places an
// order every shopper sees a new card, and when someone claims one it vanishes
// from everyone else's pool. Claiming still goes through an authenticated POST.
export function initPool() {
  const list = document.getElementById("pool-list")
  if (!list) return // only the shopper home has a pool

  const empty = document.getElementById("pool-empty")
  const csrf = document.querySelector("meta[name='csrf-token']")?.getAttribute("content")

  const refreshEmpty = () => {
    if (empty) empty.classList.toggle("hidden", list.children.length > 0)
  }

  const socket = getSocket()
  if (!socket) return
  const channel = socket.channel("orders:pool", {})
  channel.join()

  channel.on("order_created", (order) => {
    if (document.getElementById(`pool-order-${order.id}`)) return
    list.prepend(buildPoolCard(order, csrf))
    refreshEmpty()
  })

  channel.on("order_claimed", (order) => {
    const el = document.getElementById(`pool-order-${order.id}`)
    if (el) el.remove()
    refreshEmpty()
  })

  initPoolModal(list)
}

// Build a pool card with DOM APIs + textContent (never innerHTML) so a
// customer-entered item name can never inject markup. Live cards are always "New".
function buildPoolCard(order, csrf) {
  const li = document.createElement("li")
  li.id = `pool-order-${order.id}`
  li.className = "pool-card flex h-full flex-col rounded-lg border border-ui-line bg-ui-surface p-4"
  li.dataset.orderId = order.id
  li.dataset.summary = order.summary
  li.dataset.count = order.count
  li.dataset.address = order.delivery_address || ""

  const head = document.createElement("div")
  head.className = "flex items-start justify-between gap-3"

  const titleWrap = document.createElement("div")
  titleWrap.className = "flex items-center gap-2"
  const title = document.createElement("p")
  title.className = "text-sm font-semibold"
  title.textContent = `Order #${order.id}`
  const badge = document.createElement("span")
  badge.className = "rounded bg-st-blue/10 px-1.5 py-0.5 text-[10px] font-medium text-st-blue"
  badge.textContent = "New"
  titleWrap.append(title, badge)

  const count = document.createElement("span")
  count.className = "text-xs text-ui-text-3"
  count.textContent = `${order.count} items`
  head.append(titleWrap, count)

  const view = document.createElement("button")
  view.type = "button"
  view.className = "pool-view mt-2 text-left text-xs text-ui-text-2 hover:text-ui-text"
  view.textContent = order.summary

  const loc = document.createElement("p")
  loc.className = "mt-2 flex items-center gap-1 truncate text-xs text-ui-text-3"
  const pin = document.createElement("span")
  pin.setAttribute("aria-hidden", "true")
  pin.textContent = "\u{1F4CD}"
  const locText = document.createElement("span")
  locText.className = "truncate"
  locText.textContent = order.delivery_address || ""
  loc.append(pin, locText)

  const placed = document.createElement("p")
  placed.className = "mt-1 text-[11px] text-ui-text-3"
  placed.textContent = "placed just now"

  const form = document.createElement("form")
  form.action = `/jobs/${order.id}/claim`
  form.method = "post"
  form.className = "pool-accept mt-3 flex-none"
  const token = document.createElement("input")
  token.type = "hidden"
  token.name = "_csrf_token"
  token.value = csrf || ""
  const accept = document.createElement("button")
  accept.type = "submit"
  accept.className = "ui-btn w-full"
  accept.textContent = "Accept"
  form.append(token, accept)

  li.append(head, view, loc, placed, form)
  return li
}

// Quick-pickup / confirm modal: clicking a card's summary OR its Accept button opens a dialog
// with the order's details (including the full delivery location) + an Accept form. Intercepting
// the Accept form's submit keeps the no-JS path working (the form still posts without JS).
function initPoolModal(list) {
  const modal = document.getElementById("pool-modal")
  if (!modal) return

  const idEl = document.getElementById("pool-modal-id")
  const summaryEl = document.getElementById("pool-modal-summary")
  const countEl = document.getElementById("pool-modal-count")
  const locEl = document.getElementById("pool-modal-location-text")
  const form = document.getElementById("pool-modal-form")
  const closeBtn = document.getElementById("pool-modal-close")
  let lastFocused = null

  const open = (card) => {
    idEl.textContent = `#${card.dataset.orderId}`
    summaryEl.textContent = card.dataset.summary
    countEl.textContent = `${card.dataset.count} items`
    if (locEl) locEl.textContent = card.dataset.address || ""
    form.action = `/jobs/${card.dataset.orderId}/claim`
    lastFocused = document.activeElement
    modal.hidden = false
    modal.classList.remove("hidden")
    modal.classList.add("flex")
    closeBtn.focus()
  }

  const close = () => {
    modal.hidden = true
    modal.classList.add("hidden")
    modal.classList.remove("flex")
    if (lastFocused) lastFocused.focus()
  }

  list.addEventListener("click", (e) => {
    const view = e.target.closest(".pool-view")
    if (!view) return
    open(view.closest(".pool-card"))
  })

  // Accept → confirm: intercept the form submit and open the modal instead.
  list.addEventListener("submit", (e) => {
    const acceptForm = e.target.closest(".pool-accept")
    if (!acceptForm) return
    e.preventDefault()
    open(acceptForm.closest(".pool-card"))
  })

  closeBtn.addEventListener("click", close)
  modal.addEventListener("click", (e) => {
    if (e.target === modal) close()
  })
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && !modal.hidden) close()
  })
}
