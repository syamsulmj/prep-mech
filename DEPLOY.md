# Deploying PrepMech to Railway

PrepMech ships as an Elixir **release** built by the generated `Dockerfile`
(multi-stage: build → slim runtime). Railway builds the Dockerfile, provisions
PostgreSQL, and serves the app over HTTPS (which the PWA + geolocation require).

- **Migrations** run automatically on each deploy (`/app/bin/migrate`).
- **Seeds** are run once, by hand, on the live node (they broadcast over PubSub,
  so they need the running supervision tree — see §6).

---

## 0. Prerequisites
- A [Railway](https://railway.app) account.
- This repo pushed to GitHub (Railway auto-deploys on push).
- The Railway CLI for seeding/SSH: `npm i -g @railway/cli` (or `brew install railway`).

## 1. Push the release scaffolding
The repo already contains `Dockerfile`, `.dockerignore`, `rel/`, and
`lib/prep_mech/release.ex` (with `migrate/0`, `rollback/2`, `seed/0`). Commit +
push them to your deploy branch (e.g. `main`):

```bash
git add -A && git commit -m "Add Railway release (Dockerfile + release tasks)"
git push origin main
```

## 2. Create the Railway project + database
1. Railway → **New Project** → **Deploy from GitHub repo** → pick this repo.
2. In the project, **New** → **Database** → **Add PostgreSQL**.

Railway will start the first build from the Dockerfile. It's fine if this initial
build boots without all env vars yet — set them next, then redeploy.

## 3. Set environment variables (app service → Variables)
| Variable | Value | Why |
|---|---|---|
| `SECRET_KEY_BASE` | output of `mix phx.gen.secret` (run locally) | signs sessions/tokens |
| `DATABASE_URL` | `${{Postgres.DATABASE_URL}}` (Railway reference) | connects to the DB |
| `ECTO_IPV6` | `true` | **Railway's private DB network is IPv6** — without this the app can't reach Postgres |
| `PHX_HOST` | your Railway domain (see §4), e.g. `prep-mech-production.up.railway.app` | correct URL/host + WS origin |

`PORT` is injected by Railway automatically (`runtime.exs` reads it), and
`bin/server` sets `PHX_SERVER=true` — no need to set those.

## 4. Generate the public domain
App service → **Settings → Networking → Generate Domain**. Copy the domain and
put it in `PHX_HOST` (§3), then trigger a redeploy (push, or Railway → Deploy).

## 5. Run migrations automatically on deploy
App service → **Settings → Deploy → Pre-deploy Command**:

```
/app/bin/migrate
```

This runs `PrepMech.Release.migrate/0` before each new version goes live.
(One-off alternative: `railway ssh /app/bin/migrate`.)

## 6. Seed demo data (once, on the live node)
Seeds drive the `Orders` context, which **broadcasts over `Phoenix.PubSub`**, so
they must run on the **running** node (Repo + PubSub already started) — not via
`bin/prep_mech eval` (which boots a bare node without the supervision tree).

**Recommended (non-interactive):** run it on the live node via RPC:
```bash
railway link                                       # select project + app service
railway ssh /app/bin/prep_mech rpc "PrepMech.Release.seed()"
```

**Interactive remote console (what you asked about):**
```bash
railway ssh                                         # shell into the running container
/app/bin/prep_mech remote                           # IEx attached to the LIVE node
iex> PrepMech.Release.seed()                         # runs the seeder; prints the summary
# leave the console by closing the SSH session (do NOT call System.stop — that kills the server)
```

Both run against the live database and start no second web server (no port
clash), because they execute inside/attached-to the already-running release.

Demo accounts created (all password `password123`):
`customer@demo.com`, `shopper1@demo.com`, `shopper2@demo.com` — plus 6 orders
spread across the lifecycle.

## 7. Verify
- Open `https://<PHX_HOST>` → log in as `customer@demo.com` / `password123`.
- **PWA:** DevTools → Application → Manifest is installable; "Install app" works
  (Service Workers need HTTPS — Railway provides it).
- **Offline:** DevTools → Network → Offline → a previously-viewed page still loads.
- **GPS map:** drive an order to `on_delivery`; the customer's tracking page shows
  the live Leaflet map (geolocation needs HTTPS — Railway provides it).

---

## Troubleshooting
- **App can't connect to Postgres / times out:** ensure `ECTO_IPV6=true` and that
  `DATABASE_URL` references the Railway Postgres (the private URL). This is the
  most common Railway + Phoenix failure.
- **`DATABASE_URL is missing` on boot:** the variable isn't set on the *app*
  service (setting it only on the Postgres service isn't enough — reference it).
- **Wrong redirect host / WebSocket rejected:** `PHX_HOST` must match the actual
  domain (no `https://` prefix, no trailing slash).
- **Assets/PWA missing:** `assets.deploy` runs inside the Docker build; source
  static files (`priv/static/{vendor,images,manifest.json,sw.js,offline.html}`)
  are kept by `.dockerignore` (only the regenerated `priv/static/assets/` is
  excluded).
- **Re-seed / reset demo data:** re-run the §6 command — `seeds.exs` is idempotent
  (it clears demo orders + accounts first).
