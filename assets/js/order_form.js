// New-order form: add/remove line-item rows and keep the item count in sync.
// Progressive enhancement — the form works without JS (one row); this just lets
// a customer add more. Rows are cloned from a <template>.
export function initOrderForm() {
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
