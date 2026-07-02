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

## Tech stack (and a note on the deviation)

Elixir · Phoenix 1.7 (no LiveView — the Service Worker is hand-written for full control) ·
PostgreSQL · vanilla JS + self-hosted Leaflet.

> The assessment suggested PHP/MySQL; this is built on Elixir/Phoenix/PostgreSQL. The required
> architecture maps 1:1 — a PWA (Service Worker + manifest), a relational database, and a real-time
> transport. The advantage is that Elixir provides the real-time layer through built-in **Phoenix
> Channels + PubSub** and in-memory **ETS**, so live order updates and delivery tracking need **no
> extra infrastructure** (no Redis for pub/sub, no separate cache).

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

## Project layout

- `lib/prep_mech/` — domain: `Orders` (lifecycle + atomic claim), `Analytics`, `LiveLocations`
  (ephemeral GPS ETS store), `OrderEvents` (PubSub bus).
- `lib/prep_mech_web/` — controllers, HTML templates, and channels (`PoolChannel`, `OrderChannel`,
  `LocationChannel`).
- `assets/js/` — feature modules: `sw` registration, `live_region`, `pool`, offline `outbox` +
  `job_items`, `delivery_map`, `location_sender`.
- `priv/static/{sw.js,manifest.json,offline.html,vendor/leaflet.*}` — PWA + map assets.
