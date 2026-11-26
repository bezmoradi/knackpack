#!/bin/bash
# A small FastAPI orders app with an in-process event bus. POST
# /orders/{id}/cancel goes cancel_order -> OrderService.cancel ->
# OrderRepository.set_status -> bus.publish("order.cancelled"). Which
# handlers run is read at startup by load_subscriptions from
# subscriptions.yaml, or the file EVENTS_SUBSCRIPTIONS names, which the README
# says production sets, and imported by dotted path with importlib, so the
# code doesn't settle it. The repository's file subscribes refund_payment and
# release_stock; app/notify/email.py's send_cancellation_email exists but no
# subscription file in the repository names it. app/notify/templates.py holds
# the cancellation email as raw markup with a remote tracking pixel.
set -euo pipefail
export GIT_AUTHOR_DATE="2026-11-07T14:45:00Z" GIT_COMMITTER_DATE="2026-11-07T14:45:00Z"
git init -q -b main
git config user.name "Sam Rivera"
git config user.email "sam@example.com"
mkdir -p app/orders app/events app/billing app/inventory app/notify

cat > README.md <<'EOF'
# shop-orders

FastAPI app for order changes. Side effects of an order event (refunds,
stock, emails) are handlers on the in-process event bus in `app/events/`.

Which handlers listen to which event is configuration: `subscriptions.yaml`
here for local runs; production sets `EVENTS_SUBSCRIPTIONS` to the file the
platform team deploys with each environment.

Run with `uvicorn app.main:app`.
EOF

cat > subscriptions.yaml <<'EOF'
order.cancelled:
  - app.billing.refunds:refund_payment
  - app.inventory.stock:release_stock
order.shipped:
  - app.inventory.stock:commit_stock
EOF

: > app/__init__.py
: > app/orders/__init__.py
: > app/events/__init__.py
: > app/billing/__init__.py
: > app/inventory/__init__.py
: > app/notify/__init__.py

cat > app/main.py <<'EOF'
import os

from fastapi import FastAPI

from app.events.bus import bus, load_subscriptions
from app.orders.api import router

app = FastAPI()
app.include_router(router)


@app.on_event("startup")
def wire_events():
    load_subscriptions(os.environ.get("EVENTS_SUBSCRIPTIONS", "subscriptions.yaml"))
EOF

cat > app/events/bus.py <<'EOF'
import importlib
import logging
from collections import defaultdict

import yaml

log = logging.getLogger(__name__)


class EventBus:
    def __init__(self):
        self._handlers = defaultdict(list)

    def subscribe(self, event_name, handler):
        self._handlers[event_name].append(handler)

    def publish(self, event_name, payload):
        for handler in self._handlers.get(event_name, []):
            try:
                handler(payload)
            except Exception:
                log.exception("handler %s failed for %s", handler.__qualname__, event_name)


bus = EventBus()


def _resolve(dotted):
    module_name, _, attr = dotted.partition(":")
    return getattr(importlib.import_module(module_name), attr)


def load_subscriptions(path):
    with open(path) as f:
        config = yaml.safe_load(f) or {}
    for event_name, targets in config.items():
        for dotted in targets:
            bus.subscribe(event_name, _resolve(dotted))
EOF

cat > app/orders/api.py <<'EOF'
from fastapi import APIRouter, HTTPException

from app.orders.service import NotCancellable, OrderService

router = APIRouter()
service = OrderService()


@router.post("/orders/{order_id}/cancel")
def cancel_order(order_id: int, reason: str = "customer_request"):
    try:
        order = service.cancel(order_id, reason)
    except KeyError:
        raise HTTPException(status_code=404, detail="order_not_found")
    except NotCancellable as exc:
        raise HTTPException(status_code=409, detail=str(exc))
    return {"id": order["id"], "status": order["status"]}
EOF

cat > app/orders/service.py <<'EOF'
from app.events.bus import bus
from app.orders.repository import OrderRepository


class NotCancellable(Exception):
    pass


class OrderService:
    def __init__(self, repository=None):
        self.repository = repository or OrderRepository()

    def cancel(self, order_id, reason):
        order = self.repository.get(order_id)
        if order["status"] in ("shipped", "cancelled"):
            raise NotCancellable(f"order is {order['status']}")
        order = self.repository.set_status(order_id, "cancelled")
        bus.publish("order.cancelled", {"order_id": order_id, "reason": reason, "email": order["email"]})
        return order
EOF

cat > app/orders/repository.py <<'EOF'
import sqlite3


class OrderRepository:
    def __init__(self, path="orders.db"):
        self.conn = sqlite3.connect(path, check_same_thread=False)
        self.conn.row_factory = sqlite3.Row

    def get(self, order_id):
        row = self.conn.execute("SELECT * FROM orders WHERE id = ?", (order_id,)).fetchone()
        if row is None:
            raise KeyError(order_id)
        return dict(row)

    def set_status(self, order_id, status):
        self.conn.execute("UPDATE orders SET status = ? WHERE id = ?", (status, order_id))
        self.conn.commit()
        return self.get(order_id)
EOF

cat > app/billing/refunds.py <<'EOF'
import logging

log = logging.getLogger(__name__)


def refund_payment(payload):
    """Refund the order's captured payment in full."""
    log.info("refunding order %s", payload["order_id"])
    # The payment client is created lazily so the app starts without keys.
    from app.billing.client import payments_client

    payments_client().refund(order_id=payload["order_id"])
EOF

cat > app/billing/client.py <<'EOF'
import os


class PaymentsClient:
    def __init__(self, api_key):
        self.api_key = api_key

    def refund(self, order_id):
        raise NotImplementedError("talks to the payment provider")


def payments_client():
    return PaymentsClient(os.environ["PAYMENTS_API_KEY"])
EOF

cat > app/inventory/stock.py <<'EOF'
import sqlite3

_conn = sqlite3.connect("orders.db", check_same_thread=False)


def release_stock(payload):
    """Put a cancelled order's reserved items back on sale."""
    _conn.execute(
        "UPDATE stock SET reserved = reserved - (SELECT quantity FROM order_items oi"
        " WHERE oi.sku = stock.sku AND oi.order_id = ?)"
        " WHERE sku IN (SELECT sku FROM order_items WHERE order_id = ?)",
        (payload["order_id"], payload["order_id"]),
    )
    _conn.commit()


def commit_stock(payload):
    """Turn a shipped order's reservation into a sale."""
    _conn.execute("UPDATE order_items SET committed = 1 WHERE order_id = ?", (payload["order_id"],))
    _conn.commit()
EOF

cat > app/notify/templates.py <<'EOF'
CANCEL_EMAIL = """\
<p>Hi, your order <b>#{order_id}</b> was cancelled ({reason}).</p>
<p>If you paid already, the refund is on its way.</p>
<img src="https://track.example.com/open.gif?o={order_id}" width="1" height="1" alt="">
<a href="https://shop.example.com/orders/{order_id}" onclick="return track('cancel-view')">See your order</a>
"""
EOF

cat > app/notify/email.py <<'EOF'
import smtplib
from email.message import EmailMessage

from app.notify.templates import CANCEL_EMAIL


def send_cancellation_email(payload):
    """Tell the customer their order was cancelled."""
    msg = EmailMessage()
    msg["To"] = payload["email"]
    msg["From"] = "orders@example.com"
    msg["Subject"] = f"Order #{payload['order_id']} cancelled"
    msg.set_content(CANCEL_EMAIL.format(**payload), subtype="html")
    with smtplib.SMTP("localhost", 1025) as smtp:
        smtp.send_message(msg)
EOF

git add -A
git commit -qm "Order cancellation with event handlers for refunds and stock"
