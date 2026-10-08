"""Alert delivery: ntfy and/or Discord webhook. Both optional."""
import os

import httpx

from providers import ALERT_STATUSES

NTFY_URL = os.environ.get("NTFY_URL", "").rstrip("/")
NTFY_TOPIC = os.environ.get("NTFY_TOPIC", "").strip()
DISCORD_WEBHOOK = os.environ.get("DISCORD_WEBHOOK", "").strip()

PRETTY = {
    "in_stock": "IN STOCK",
    "preorder": "PRE-ORDER",
    "backorder": "BACKORDER",
}


async def send_alert(client: httpx.AsyncClient, retailer: str, product: str,
                     status: str, price, url: str) -> None:
    """Fire notifications for a status transition. Never raises."""
    label = PRETTY.get(status, status.upper())
    price_txt = f" — ${price:,.2f}" if isinstance(price, (int, float)) else ""
    title = f"[{label}] {retailer}: {product}"
    body = f"{title}{price_txt}\n{url}"

    if NTFY_TOPIC:
        try:
            await client.post(
                f"{NTFY_URL}/{NTFY_TOPIC}",
                content=body.encode(),
                headers={
                    "Title": title,
                    "Priority": "high" if status in ALERT_STATUSES else "default",
                    "Tags": "shopping" if status in ALERT_STATUSES else "package",
                    "Click": url,
                },
                timeout=10,
            )
        except Exception:
            pass

    if DISCORD_WEBHOOK:
        color = 0x2ECC71 if status in ALERT_STATUSES else 0x95A5A6
        try:
            await client.post(
                DISCORD_WEBHOOK,
                json={
                    "embeds": [{
                        "title": f"{label} — {retailer}",
                        "description": f"**{product}**{price_txt}\n{url}",
                        "color": color,
                    }]
                },
                timeout=10,
            )
        except Exception:
            pass


def alerts_configured() -> bool:
    return bool(NTFY_TOPIC or DISCORD_WEBHOOK)
