"""Stock source providers.

Each provider knows how to query one retailer for one product and returns a
(status, price, detail) triple. Two providers are wired up live:

  * psdirect  - PlayStation Direct. Parses the schema.org/Offer availability
                markup embedded in the server-rendered product page.
  * bestbuy   - Best Buy official developer API (needs BESTBUY_API_KEY).

Retailers that serve bot walls to a datacenter IP (Walmart, Target, GameStop,
Newegg, Sam's Club, B&H, Micro Center, Amazon) are listed in UNSUPPORTED so the
dashboard can show coverage honestly instead of reporting false "out of stock".
They need browser automation or a third-party data feed; see README.
"""
from __future__ import annotations

import os
import re
from dataclasses import dataclass

import httpx

# --- status vocabulary -------------------------------------------------------
IN_STOCK = "in_stock"
OUT_OF_STOCK = "out_of_stock"
PREORDER = "preorder"
BACKORDER = "backorder"
UNKNOWN = "unknown"
BLOCKED = "blocked"
ERROR = "error"
SKIPPED = "skipped"

ALERT_STATUSES = {IN_STOCK, PREORDER}

UA = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
)
HEADERS = {
    "User-Agent": UA,
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
    "Cache-Control": "no-cache",
}

SCHEMA_MAP = {
    "InStock": IN_STOCK,
    "OutOfStock": OUT_OF_STOCK,
    "SoldOut": OUT_OF_STOCK,
    "PreOrder": PREORDER,
    "PreSale": PREORDER,
    "BackOrder": BACKORDER,
    "LimitedAvailability": IN_STOCK,
    "OnlineOnly": IN_STOCK,
}
AVAIL_RE = re.compile(
    r'itemprop="availability"\s+href="(?:https?:)?//schema\.org/([A-Za-z]+)"'
)
PRICE_RE = re.compile(r'itemprop="price"\s+content="([\d.]+)"')


@dataclass
class Provider:
    name: str          # stable id, used as the DB key
    retailer: str      # display name
    product: str
    url: str
    kind: str          # psdirect | bestbuy
    sku: str | None = None
    region: str = "US"
    note: str | None = None

    async def check(self, client: httpx.AsyncClient):
        if self.kind == "psdirect":
            return await self._psdirect(client)
        if self.kind == "bestbuy":
            return await self._bestbuy(client)
        return (UNKNOWN, None, f"no handler for kind={self.kind}")

    # --- PlayStation Direct ------------------------------------------------
    async def _psdirect(self, client: httpx.AsyncClient):
        r = await client.get(self.url, headers=HEADERS)
        if r.status_code in (403, 429):
            return (BLOCKED, None, f"HTTP {r.status_code}")
        if r.status_code >= 400:
            return (ERROR, None, f"HTTP {r.status_code}")

        html = r.text
        m = AVAIL_RE.search(html)
        price_m = PRICE_RE.search(html)
        price = float(price_m.group(1)) if price_m else None

        if m:
            status = SCHEMA_MAP.get(m.group(1), UNKNOWN)
            return (status, price, f"schema.org/{m.group(1)}")

        # Fallback heuristics if the structured markup is ever missing.
        low = html.lower()
        if "add to cart" in low and "currently unavailable" not in low:
            return (IN_STOCK, price, "heuristic: add-to-cart")
        if "currently unavailable" in low or "out of stock" in low:
            return (OUT_OF_STOCK, price, "heuristic: unavailable")
        if "coming soon" in low:
            return (PREORDER, price, "heuristic: coming-soon")
        return (UNKNOWN, price, "no availability marker found")

    # --- Best Buy official API --------------------------------------------
    async def _bestbuy(self, client: httpx.AsyncClient):
        key = os.environ.get("BESTBUY_API_KEY", "").strip()
        if not key:
            return (SKIPPED, None, "set BESTBUY_API_KEY to enable")
        r = await client.get(
            f"https://api.bestbuy.com/v1/products/{self.sku}.json",
            params={
                "apiKey": key,
                "show": "name,onlineAvailability,orderable,salePrice,url,sku",
            },
        )
        if r.status_code != 200:
            return (ERROR, None, f"HTTP {r.status_code}: {r.text[:120]}")
        data = r.json()
        price = data.get("salePrice")
        if data.get("orderable") and data.get("onlineAvailability"):
            return (IN_STOCK, price, "api: orderable")
        if data.get("onlineAvailability"):
            return (IN_STOCK, price, "api: onlineAvailability")
        return (OUT_OF_STOCK, price, "api: not available")


# --- Live sources ------------------------------------------------------------
# Only sources that actually return a real answer are listed. Blocked retailers
# (Walmart, Target, GameStop, Newegg, Sam's Club, B&H, Micro Center, Amazon,
# Antonline) are intentionally omitted; see README for how to add them.
PROVIDERS: list[Provider] = [
    Provider(
        name="psdirect_us_pro_2tb",
        retailer="PlayStation Direct",
        product="PS5 Pro Console (2TB)",
        url="https://direct.playstation.com/en-us/buy-consoles/playstation5-pro-console-2-tb",
        kind="psdirect",
    ),
]

# Best Buy is only polled when an official API key is configured, so it never
# shows up as a broken "skipped" source otherwise.
if os.environ.get("BESTBUY_API_KEY", "").strip():
    PROVIDERS.append(
        Provider(
            name="bestbuy_6562841",
            retailer="Best Buy",
            product="PS5 Pro Console",
            url="https://www.bestbuy.com/site/playstation-5-pro/6562841.p",
            kind="bestbuy",
            sku="6562841",
        )
    )
