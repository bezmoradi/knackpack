#!/bin/bash
# A small asyncio order service with an audit trail, a payment gateway client
# and a background metrics flush, committed with its audit rules, plus an
# uncommitted change that adds refunds.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p app docs
touch app/__init__.py
cat > pyproject.toml <<'TOML'
[project]
name = "order-service"
version = "0.9.1"
requires-python = ">=3.11"
dependencies = []
TOML
cat > app/events.py <<'PY'
"""Events written to the audit trail."""

from dataclasses import dataclass
from decimal import Decimal


@dataclass(frozen=True)
class CancelEvent:
    order_id: str
    actor: str


@dataclass(frozen=True)
class RefundEvent:
    order_id: str
    amount: Decimal
    actor: str
    receipt_id: str
PY
cat > app/audit.py <<'PY'
"""The audit trail. Production configures a database-backed store at startup."""

from __future__ import annotations

import time
from typing import Any, Protocol


class AuditStore(Protocol):
    async def append(self, row: dict[str, Any]) -> None: ...


class MemoryAuditStore:
    def __init__(self) -> None:
        self.rows: list[dict[str, Any]] = []

    async def append(self, row: dict[str, Any]) -> None:
        self.rows.append(row)


_store: AuditStore = MemoryAuditStore()


def configure(store: AuditStore) -> None:
    global _store
    _store = store


async def record(event: object) -> None:
    """Write event to the audit trail; raises if the store rejects it."""
    row = {"type": type(event).__name__, "at": time.time(), **vars(event)}
    await _store.append(row)
PY
cat > app/payments.py <<'PY'
"""The payment gateway client. Production configures the gateway at startup."""

from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal
from typing import Protocol


class Gateway(Protocol):
    async def refund(self, order_id: str, amount: Decimal) -> str: ...


@dataclass(frozen=True)
class Receipt:
    receipt_id: str


_gateway: Gateway | None = None


def configure(gateway: Gateway) -> None:
    global _gateway
    _gateway = gateway


async def refund(order_id: str, amount: Decimal) -> Receipt:
    """Refund part or all of an order's captured payment.

    The gateway rejects a refund larger than what is left of the captured
    amount, so callers don't track it themselves.
    """
    if _gateway is None:
        raise RuntimeError("payment gateway not configured")
    return Receipt(receipt_id=await _gateway.refund(order_id, amount))
PY
cat > app/metrics.py <<'PY'
"""Counters, flushed to the log by a background task."""

import asyncio
import logging
from collections import Counter

FLUSH_INTERVAL_SECONDS = 10.0
log = logging.getLogger("metrics")

counters: Counter[str] = Counter()
_tasks: set[asyncio.Task[None]] = set()


async def _flush_forever() -> None:
    while True:
        await asyncio.sleep(FLUSH_INTERVAL_SECONDS)
        snapshot = dict(counters)
        counters.clear()
        # The log shipper forwards these lines to the metrics backend.
        log.info("flush", extra={"counters": snapshot})


def start() -> None:
    task = asyncio.create_task(_flush_forever(), name="metrics-flush")
    # Keep a reference until the task finishes; the loop holds only weak ones.
    _tasks.add(task)
    task.add_done_callback(_tasks.discard)


async def stop() -> None:
    for task in list(_tasks):
        task.cancel()
    await asyncio.gather(*_tasks, return_exceptions=True)
PY
cat > app/orders.py <<'PY'
"""Order handlers."""

from app import audit, metrics
from app.events import CancelEvent


async def cancel_order(order_id: str, actor: str) -> dict:
    await audit.record(CancelEvent(order_id=order_id, actor=actor))
    metrics.counters["orders.cancelled"] += 1
    return {"status": "cancelled", "order_id": order_id}
PY
cat > app/handlers.py <<'PY'
"""Maps API actions to handlers."""

from app.orders import cancel_order

HANDLERS = {
    "orders.cancel": cancel_order,
}
PY
cat > app/main.py <<'PY'
"""Process entry point: starts the background tasks and stops them on SIGTERM."""

import asyncio
import signal

from app import metrics


async def serve(stop: asyncio.Event) -> None:
    metrics.start()
    try:
        await stop.wait()
    finally:
        await metrics.stop()


def main() -> None:
    async def run() -> None:
        stop = asyncio.Event()
        loop = asyncio.get_running_loop()
        for sig in (signal.SIGINT, signal.SIGTERM):
            loop.add_signal_handler(sig, stop.set)
        await serve(stop)

    asyncio.run(run())


if __name__ == "__main__":
    main()
PY
cat > docs/audit.md <<'MD'
# Audit trail

Every action that moves money or changes an order's state writes an event to
the audit trail through `app.audit.record`.

- A refund must be audited before the response is sent. Finance reconciles
  the gateway's refunds against the audit trail every night, and a refund with
  no audit event is treated as an incident.
- If the audit write fails, the request fails. Never answer success for an
  action the trail doesn't show.
MD
git add -A
git commit -qm "Add order cancellation with an audit trail"
cat > app/refunds.py <<'PY'
"""Refund handler."""

from decimal import Decimal

from app import audit, metrics, payments
from app.events import RefundEvent


async def refund(order_id: str, amount: Decimal, actor: str) -> dict:
    if amount <= 0:
        raise ValueError("refund amount must be positive")
    receipt = await payments.refund(order_id, amount)
    audit.record(RefundEvent(order_id=order_id, amount=amount, actor=actor, receipt_id=receipt.receipt_id))
    metrics.counters["orders.refunded"] += 1
    return {"status": "refunded", "order_id": order_id, "receipt_id": receipt.receipt_id}
PY
cat > app/handlers.py <<'PY'
"""Maps API actions to handlers."""

from app.orders import cancel_order
from app.refunds import refund

HANDLERS = {
    "orders.cancel": cancel_order,
    "orders.refund": refund,
}
PY
