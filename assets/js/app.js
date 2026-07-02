// Entry point. Each feature lives in its own module and exposes an `init*`
// function that no-ops unless the elements it needs are on the current page,
// so it's safe to run them all everywhere.
//
// phoenix_html handles method=PUT/DELETE on forms and buttons.
import "phoenix_html"

import {initOrderForm} from "./order_form"
import {initLiveRegion} from "./live_region"
import {initPool} from "./pool"
import {initPwa} from "./pwa"
import {initJobItems} from "./job_items"
import {initDeliveryMap} from "./delivery_map"
import {initLocationSender} from "./location_sender"

document.addEventListener("DOMContentLoaded", () => {
  initOrderForm()
  initLiveRegion()
  initPool()
  initPwa()
  initJobItems()
  initDeliveryMap()
  initLocationSender()
})
