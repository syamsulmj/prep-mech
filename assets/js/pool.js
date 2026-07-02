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
// customer-entered item name can never inject markup.
function buildPoolCard(order, csrf) {
  const li = document.createElement("li")
  li.id = `pool-order-${order.id}`
  li.className = "pool-card flex h-full flex-col rounded-lg border border-ui-line bg-ui-surface p-4"
  li.dataset.orderId = order.id
  li.dataset.summary = order.summary
  li.dataset.count = order.count

  const head = document.createElement("div")
  head.className = "flex items-start justify-between gap-3"
  const title = document.createElement("p")
  title.className = "text-sm font-semibold"
  title.textContent = `Order #${order.id}`
  const count = document.createElement("span")
  count.className = "text-xs text-ui-text-3"
  count.textContent = `${order.count} items`
  head.append(title, count)

  const view = document.createElement("button")
  view.type = "button"
  view.className = "pool-view mt-2 flex-1 text-left text-xs text-ui-text-2 hover:text-ui-text"
  view.textContent = order.summary

  const form = document.createElement("form")
  form.action = `/jobs/${order.id}/claim`
  form.method = "post"
  form.className = "pool-accept mt-3"
  const token = document.createElement("input")
  token.type = "hidden"
  token.name = "_csrf_token"
  token.value = csrf || ""
  const accept = document.createElement("button")
  accept.type = "submit"
  accept.className = "ui-btn w-full"
  accept.textContent = "Accept"
  form.append(token, accept)

  li.append(head, view, form)
  return li
}

// Quick-pickup modal: clicking a card's summary opens a dialog with the order's
// details + an Accept form. Focus moves in on open and back to the trigger on
// close; Escape and backdrop-click both close it.
function initPoolModal(list) {
  const modal = document.getElementById("pool-modal")
  if (!modal) return

  const idEl = document.getElementById("pool-modal-id")
  const summaryEl = document.getElementById("pool-modal-summary")
  const countEl = document.getElementById("pool-modal-count")
  const form = document.getElementById("pool-modal-form")
  const closeBtn = document.getElementById("pool-modal-close")
  let lastFocused = null

  const open = (card) => {
    idEl.textContent = `#${card.dataset.orderId}`
    summaryEl.textContent = card.dataset.summary
    countEl.textContent = `${card.dataset.count} items`
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
  closeBtn.addEventListener("click", close)
  modal.addEventListener("click", (e) => {
    if (e.target === modal) close()
  })
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && !modal.hidden) close()
  })
}
