# PrepMech

An installable, offline-capable, real-time **order-tracking PWA** for a personal-shopper /
grocery-runner service. Two roles:

- **Customer** — create orders and track them live (status timeline + live delivery map).
- **Personal Shopper** — claim jobs from a shared pool, check items off (works offline), and
  drive an order through to delivery.

**Live demo:** https://prep-mech-production.up.railway.app
Demo accounts (password `password123` for all):

| Role | Email |
|---|---|
| Customer | `customer@demo.com` |
| Personal Shopper | `shopper1@demo.com`, `shopper2@demo.com` |

## Features

- **Installable PWA** — Web App Manifest + a hand-written Service Worker; the app shell and
  previously-visited pages load offline.
- **Offline action queue** — a shopper can mark items Picked/Unavailable with no signal; the
  actions are queued in IndexedDB and replay automatically on reconnect.
- **Real-time order tracking** — status changes stream to the customer live over Phoenix Channels.
- **Live GPS delivery** — during delivery the shopper's location is streamed over a channel and
  rendered on a Leaflet/OpenStreetMap map on the customer's page (ephemeral: ETS + PubSub, never
  persisted).
- **Atomic job claiming** — first-writer-wins claim from the pool via a single conditional UPDATE.

## Tech stack

Elixir · Phoenix 1.7 (no LiveView — the Service Worker is hand-written for full control) ·
PostgreSQL · vanilla JS + self-hosted Leaflet · OpenStreetMap tiles.

The real-time layer (live order updates and delivery tracking) is built on Phoenix's built-in
**Channels + PubSub** and in-memory **ETS**, so it needs no extra infrastructure — no Redis for
pub/sub, no separate cache.

## Prerequisites

- **[asdf](https://asdf-vm.com/)** — versions are pinned in [`.tool-versions`](.tool-versions)
  (Elixir 1.18.4, Erlang/OTP 27.3, Node 24, Yarn). Install them with:
  ```bash
  asdf install
  ```
  (Or install those versions of Elixir/Erlang manually if you don't use asdf.)
- **PostgreSQL** running locally (default dev config expects user/pass `postgres` on `localhost`;
  see `config/dev.exs`).

## Run it locally

```bash
mix setup                      # deps + create/migrate DB + build assets
mix run priv/repo/seeds.exs    # demo accounts + orders across the lifecycle (idempotent)
mix phx.server                 # http://localhost:4000
```

Log in with any demo account above. To exercise the PWA: open in Chrome, install it
(Application → Manifest), then use DevTools → Network → **Offline** to see the app shell load and
item check-offs queue + sync on reconnect.

## Tests

```bash
mix test
```

## Deployment

Deployed to Railway from a generated Docker release. Full step-by-step (env vars, migrations,
seeding via the remote console) is in **[DEPLOY.md](DEPLOY.md)**.

## Project structure

```
lib/
  prep_mech/                     # domain (business logic — no web concerns)
    accounts.ex                  # registration + auth (bcrypt)
    orders.ex                    # order lifecycle: create, atomic claim, advance, item status
    analytics.ex                 # read-only dashboard counts
    order_events.ex             # PubSub event bus (topic names + message shapes)
    live_locations.ex            # ephemeral GPS store (public ETS table, no DB)
    application.ex               # OTP supervision tree
    repo.ex
    repo/
      accounts/user.ex           # User schema (role: customer | shopper)
      orders/order.ex            # Order schema (status enum lifecycle)
      orders/line_item.ex        # LineItem schema (pickup_status enum)
    release.ex                   # prod release tasks: migrate / rollback / seed

  prep_mech_web/                 # web layer
    router.ex                    # pipelines + routes (browser, role-gated scopes)
    endpoint.ex                  # Plug.Static, sockets, session
    plugs/auth.ex                # fetch_current_user, ensure_authenticated, require_role
    channels/
      user_socket.ex             # token-authenticated socket
      pool_channel.ex            # realtime pool add/remove for shoppers
      order_channel.ex           # customer order/list live updates
      location_channel.ex        # live GPS: shopper pushes, customer receives
    controllers/
      page_controller.ex         # role-aware home ("/")
      order_controller.ex        # customer: new / create / show (tracking)
      job_controller.ex          # shopper: claim / show / advance / set_item
      session_controller.ex      # login / signup / logout
      *_html/*.html.heex         # server-rendered templates
    components/
      core_components.ex         # shared UI: status_chip, order_stepper, item_summary, ...
      layouts/{root,app}.html.heex

assets/js/                       # progressively-enhanced vanilla JS (esbuild-bundled)
  app.js                         # entry point — wires the init* modules
  socket.js                      # single shared authenticated Phoenix socket
  live_region.js                 # customer realtime: re-fetch + swap #live-region
  pool.js                        # shopper pool: realtime cards + accept-confirm modal
  order_form.js                  # dynamic line-item rows on the new-order form
  pwa.js                         # Service Worker registration + offline banner
  outbox.js                      # IndexedDB outbox (offline mutation queue)
  job_items.js                   # offline item toggles: optimistic + queue + drain
  delivery_map.js                # customer live delivery map (Leaflet)
  location_sender.js             # shopper GPS streaming (geolocation → channel)

priv/
  repo/migrations/               # users, orders, line_items
  repo/seeds.exs                 # demo accounts + orders across the lifecycle
  static/                        # served at "/"
    sw.js                        # hand-written Service Worker (Cache Storage API)
    manifest.json                # Web App Manifest
    offline.html                 # self-contained offline fallback page
    images/                      # app icons (192/512) + logo
    vendor/leaflet.{js,css}      # self-hosted Leaflet

test/                            # ExUnit: domain, channels, controllers, view helpers
Dockerfile / DEPLOY.md           # production release + deploy runbook
```
