"""PS5 Pro stock monitor.

FastAPI app that polls stock sources on an interval, stores history in SQLite,
serves a dashboard, and fires alerts on stock transitions.
"""
from __future__ import annotations

import asyncio
import contextlib
import os
from datetime import datetime, timezone

import httpx
from fastapi import FastAPI
from fastapi.responses import FileResponse, JSONResponse

import db
import notify
from providers import ALERT_STATUSES, ERROR, PROVIDERS

INTERVAL = max(30, int(os.environ.get("CHECK_INTERVAL", "180")))
TIMEOUT = float(os.environ.get("REQUEST_TIMEOUT", "20"))

app = FastAPI(title="PS5 Pro Stock Monitor")
_run_lock = asyncio.Lock()


async def run_checks(trigger: str = "schedule") -> list[dict]:
    """Poll every source once. Serialised so manual + scheduled runs don't stack."""
    async with _run_lock:
        results = []
        async with httpx.AsyncClient(
            timeout=TIMEOUT, follow_redirects=True, http2=False
        ) as client:
            for p in PROVIDERS:
                try:
                    status, price, detail = await p.check(client)
                except Exception as exc:  # noqa: BLE001
                    status, price, detail = ERROR, None, f"{type(exc).__name__}: {exc}"
                try:
                    prev = db.record_check(p.retailer, p.product, status, price, detail, p.url)
                except Exception as exc:  # noqa: BLE001
                    prev, status = None, ERROR
                    detail = f"db error: {exc}"

                if prev is not None and status in ALERT_STATUSES and prev not in ALERT_STATUSES:
                    await notify.send_alert(client, p.retailer, p.product, status, price, p.url)
                results.append({
                    "retailer": p.retailer, "status": status,
                    "price": price, "detail": detail,
                })
        db.set_meta("last_run", db.now_iso())
        db.set_meta("last_trigger", trigger)
        return results


async def _loop() -> None:
    await asyncio.sleep(3)  # let the server bind first
    while True:
        try:
            await run_checks("schedule")
        except Exception:  # noqa: BLE001
            pass
        await asyncio.sleep(INTERVAL)


@contextlib.asynccontextmanager
async def lifespan(_: FastAPI):
    db.init_db()
    task = asyncio.create_task(_loop())
    try:
        yield
    finally:
        task.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await task


app.router.lifespan_context = lifespan
HERE = os.path.dirname(__file__)


@app.get("/")
async def index():
    return FileResponse(os.path.join(HERE, "templates", "index.html"))


@app.get("/api/status")
async def status():
    return JSONResponse({
        "updated": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "last_run": db.get_meta("last_run"),
        "interval": INTERVAL,
        "alerts_configured": notify.alerts_configured(),
        "sources": db.latest(),
        "events": db.events(40),
    })


@app.post("/api/check")
async def check_now():
    results = await run_checks("manual")
    return {"ok": True, "results": results}


@app.get("/healthz")
async def healthz():
    return {"ok": True, "last_run": db.get_meta("last_run")}
