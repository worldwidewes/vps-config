# PS5 Pro Stock Monitor

A self-hosted stock tracker (rpilocator-style) for the PS5 Pro. It polls each
source on an interval, stores every check plus stock transitions in SQLite,
serves a dashboard, and fires alerts when something comes back in stock.

- Dashboard: <https://ps5stock.weschance.com>
- Container: `ps5stock-5c2b-app-1` (Docker Compose, routed by Traefik)
- Data: named volume `ps5stock-5c2b_stock-data` → `/data/stock.db`

## Architecture

```
browser ──HTTPS──▶ Cloudflare ──▶ Traefik (:443) ──▶ app container (:8000)
                                                      │
                              background loop every CHECK_INTERVAL seconds
                                                      │
                       ┌──────────────────┬───────────┴────────────┐
                  PlayStation Direct    Best Buy API      SQLite (checks + events)
                    (scrape)             (optional)
                                                      │
                                            alerts: ntfy / Discord
```

- `app/main.py` — FastAPI app, background polling loop, JSON API, dashboard.
- `app/providers.py` — one class per source. Add a `Provider` here to add a source.
- `app/db.py` — SQLite. `checks` = every observation, `events` = transitions only.
- `app/notify.py` — optional ntfy and Discord delivery.

## What actually works from a datacenter IP

This matters. Most major retailers block bots at the edge, so a naive scraper
reports "blocked/unknown" instead of a real answer. Verified from this VPS:

| Retailer | Direct fetch | Method |
|---|---|---|
| **PlayStation Direct** | ✅ 200 | scrape `schema.org/Offer` availability + price |
| **Best Buy** | ❌ connection reset | official API; source auto-appears once `BESTBUY_API_KEY` is set |
| Walmart | ❌ PerimeterX CAPTCHA | needs browser automation / proxy |
| Newegg, Sam's Club | ❌ CAPTCHA | needs browser automation / proxy |
| GameStop, B&H, Micro Center, Antonline | ❌ 403 | needs browser automation / proxy |
| Target, Amazon | ❌ bot detection | needs browser automation / proxy |

Only working sources are polled and shown. Best Buy is registered automatically
when a key is present; the blocked retailers are deliberately not listed so the
dashboard never shows a false "out of stock". See "Add a source" to wire them up.

## Alerts

Edit `.env`, then `docker compose up -d`:

```sh
# ntfy (phone push). Install the ntfy app and subscribe to your topic.
NTFY_TOPIC=wes-ps5-pro-alerts

# or Discord
DISCORD_WEBHOOK=https://discord.com/api/webhooks/...
```

Alerts fire only on a transition *into* `in_stock` or `preorder`, not on every poll.

## Add a source

1. Append a `Provider(...)` to `PROVIDERS` in `app/providers.py` with a `kind`
   that has a handler in `Provider.check`. The PlayStation Direct handler is a
   good template for any server-rendered page with schema.org markup.
2. `docker compose up -d --build`

### Adding a blocked retailer properly

Plain `httpx` will not get past PerimeterX/Akamai. Realistic options, best first:

1. **Official APIs** — Best Buy developer API (already supported), Walmart
   affiliate/Impact API, Target RedSky. Legitimate, stable, but may need approval.
2. **Browser automation with stealth** — Playwright + a stealth patch, or
   Camoufox, running headless in a container. You already run `browser-use-mcp`;
   you could reuse it instead of adding another browser. Datacenter IPs are
   still frequently blocked, so this alone often is not enough.
3. **Residential/ISP proxies** — the usual fix for IP-based blocking. Costs money.
4. **Third-party stock feeds** — paid aggregator APIs; least maintenance.

Each blocked source should be its own container/task so a slow browser render
never stalls the plain-HTTP pollers.

## Operations

```sh
cd /docker/ps5stock-5c2b
docker compose logs -f            # tail logs
docker compose up -d --build      # apply code changes
docker compose down               # stop (keeps the volume/data)
curl -s https://ps5stock.weschance.com/api/status | python3 -m json.tool
```

Change the poll frequency with `CHECK_INTERVAL` in `.env` (seconds, min 30).
Change the hostname with `TRAEFIK_SUBDOMAIN` in `.env` (needs the wildcard DNS
record, which `*.weschance.com` already has).

## API

- `GET /api/status` — current state, recent events, unsupported list, config.
- `POST /api/check` — run an immediate check (used by the dashboard button).
- `GET /healthz` — liveness + last run time.
