// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"

// ---------------------------------------------------------------------------
// New-order form: add/remove line-item rows and keep the item count in sync.
// Progressive enhancement — the form works without JS (one row); this just
// lets a customer add more. Rows are cloned from a <template>.
// ---------------------------------------------------------------------------
function initOrderForm() {
  const list = document.getElementById("line-items")
  const addBtn = document.getElementById("add-item")
  const tmpl = document.getElementById("line-item-row")
  const countEl = document.getElementById("item-count")
  if (!list || !addBtn || !tmpl) return

  // Re-number every row's field names to contiguous indices. Plug parses
  // `line_items[0][name]` / `line_items[1][name]` into separate maps, whereas
  // `line_items[][name]` would collapse into one — so the index is required.
  const sync = () => {
    const rows = list.querySelectorAll(".line-item")
    rows.forEach((row, i) => {
      const name = row.querySelector(".li-name")
      const qty = row.querySelector(".li-qty")
      if (name) name.name = `order[line_items][${i}][name]`
      if (qty) qty.name = `order[line_items][${i}][quantity]`
    })
    if (countEl) {
      countEl.textContent = `${rows.length} ${rows.length === 1 ? "item" : "items"}`
    }
  }

  addBtn.addEventListener("click", () => {
    list.appendChild(tmpl.content.firstElementChild.cloneNode(true))
    sync()
  })

  list.addEventListener("click", (e) => {
    const remove = e.target.closest(".remove-item")
    if (!remove) return
    if (list.querySelectorAll(".line-item").length > 1) {
      remove.closest(".line-item").remove()
      sync()
    }
  })

  sync()
}

document.addEventListener("DOMContentLoaded", initOrderForm)
// Establish Phoenix Socket and LiveView configuration.
// import {Socket} from "phoenix"
// import {LiveSocket} from "phoenix_live_view"
// import topbar from "../vendor/topbar"

// let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
// let liveSocket = new LiveSocket("/live", Socket, {
//   longPollFallbackMs: 2500,
//   params: {_csrf_token: csrfToken}
// })

// Show progress bar on live navigation and form submits
// topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
// window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
// window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
// liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
// window.liveSocket = liveSocket

