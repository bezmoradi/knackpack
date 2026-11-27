#!/bin/bash
# A small Flask orders service: POST /orders goes through OrderService, which
# takes its payment handler from a registry keyed by a configured provider
# name, charges, saves through OrderRepository and sends a confirmation email.
set -euo pipefail
export GIT_AUTHOR_DATE="2026-11-10T10:00:00Z" GIT_COMMITTER_DATE="2026-11-10T10:00:00Z"
git init -q -b main
git config user.name "Priya Natarajan"
git config user.email "priya@example.com"
mkdir -p orders/payments

cat > README.md <<'EOF'
# orders

The orders API for the shop. A Flask app in `orders/` that takes orders,
charges them through the configured payment provider, stores them in SQLite
and emails the customer a confirmation.

Settings come from `settings.toml`; every deployment overrides them with
`ORDERS_*` environment variables (see `orders/config.py`).

Run locally with `flask --app orders.app run`.
EOF

cat > settings.toml <<'EOF'
[database]
path = "orders.db"

[payments]
provider = "sandbox"

[mail]
host = "localhost"
port = 1025
sender = "orders@example.com"

[site]
base_url = ""
logo_path = "/static/logo.png"
EOF

: > orders/__init__.py
: > orders/payments/__init__.py

cat > orders/config.py <<'EOF'
import os
import tomllib
from dataclasses import dataclass
from pathlib import Path

SETTINGS_FILE = Path(__file__).resolve().parent.parent / "settings.toml"


@dataclass(frozen=True)
class Settings:
    database_path: str
    payment_provider: str
    mail_host: str
    mail_port: int
    mail_sender: str
    base_url: str
    logo_path: str


def load_settings() -> Settings:
    with SETTINGS_FILE.open("rb") as f:
        data = tomllib.load(f)
    env = os.environ
    return Settings(
        database_path=env.get("ORDERS_DATABASE_PATH", data["database"]["path"]),
        payment_provider=env.get("ORDERS_PAYMENT_PROVIDER", data["payments"]["provider"]),
        mail_host=env.get("ORDERS_MAIL_HOST", data["mail"]["host"]),
        mail_port=int(env.get("ORDERS_MAIL_PORT", data["mail"]["port"])),
        mail_sender=env.get("ORDERS_MAIL_SENDER", data["mail"]["sender"]),
        base_url=env.get("ORDERS_BASE_URL", data["site"]["base_url"]),
        logo_path=env.get("ORDERS_LOGO_PATH", data["site"]["logo_path"]),
    )
EOF

cat > orders/app.py <<'EOF'
from flask import Flask, abort, request

from .cache import order_cache
from .config import load_settings
from .notifications import OrderNotifier, SmtpMailer
from .payments.charging import PaymentDeclined, charge
from .payments.registry import get_handler
from .repository import OrderRepository
from .service import OrderService

app = Flask(__name__)
settings = load_settings()
repository = OrderRepository(settings.database_path)
notifier = OrderNotifier(SmtpMailer(settings), settings)
order_service = OrderService(settings, repository, notifier)


@app.post("/orders")
def create_order():
    payload = request.get_json(force=True)
    items = payload.get("items") or []
    if not items or "email" not in payload:
        abort(400)
    try:
        order = order_service.place_order(
            customer_email=payload["email"],
            customer_name=payload.get("name", ""),
            items=items,
        )
    except PaymentDeclined as exc:
        return {"error": "payment_declined", "reason": str(exc)}, 402
    return {"id": order.id, "status": order.status}, 201


@app.get("/orders/<int:order_id>")
def get_order(order_id):
    cached = order_cache.get(order_id)
    if cached is not None:
        return cached
    order = repository.get(order_id)
    if order is None:
        abort(404)
    body = order.to_dict()
    order_cache.set(order_id, body)
    return body


@app.post("/orders/<int:order_id>/charge")
def recharge_order(order_id):
    """Support tool: try the payment again for an order whose charge failed."""
    order = repository.get(order_id)
    if order is None:
        abort(404)
    if order.status != "payment_failed":
        return {"error": "not_retryable", "status": order.status}, 409
    handler = get_handler(settings.payment_provider, settings)
    try:
        payment = charge(handler, order.total_cents, order.currency, order.reference)
    except PaymentDeclined as exc:
        return {"error": "payment_declined", "reason": str(exc)}, 402
    repository.mark_paid(order.id, payment.id)
    return {"id": order.id, "status": "paid"}
EOF

cat > orders/service.py <<'EOF'
import uuid
from dataclasses import asdict, dataclass, field

from .payments.charging import PaymentDeclined, charge
from .payments.registry import get_handler


@dataclass
class Order:
    customer_email: str
    customer_name: str
    items: list
    currency: str = "EUR"
    status: str = "new"
    payment_id: str | None = None
    id: int | None = None
    reference: str = field(default_factory=lambda: uuid.uuid4().hex[:12])

    @property
    def total_cents(self) -> int:
        return sum(int(i["price_cents"]) * int(i.get("quantity", 1)) for i in self.items)

    def to_dict(self) -> dict:
        data = asdict(self)
        data["total_cents"] = self.total_cents
        return data


class OrderService:
    def __init__(self, settings, repository, notifier):
        self.settings = settings
        self.repository = repository
        self.notifier = notifier

    def place_order(self, customer_email, customer_name, items) -> Order:
        order = Order(customer_email=customer_email, customer_name=customer_name, items=items)
        handler = get_handler(self.settings.payment_provider, self.settings)
        try:
            payment = charge(handler, order.total_cents, order.currency, order.reference)
        except PaymentDeclined:
            order.status = "payment_failed"
            self.repository.save(order)
            raise
        order.payment_id = payment.id
        order.status = "paid"
        self.repository.save(order)
        self.notifier.send_confirmation(order)
        return order

    def estimate_charge(self, items) -> int:
        """Total in cents for a basket, for the checkout summary."""
        return Order(customer_email="", customer_name="", items=items).total_cents
EOF

cat > orders/repository.py <<'EOF'
import json
import sqlite3

SCHEMA = """
CREATE TABLE IF NOT EXISTS orders (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    reference TEXT NOT NULL UNIQUE,
    customer_email TEXT NOT NULL,
    customer_name TEXT NOT NULL,
    items TEXT NOT NULL,
    currency TEXT NOT NULL,
    status TEXT NOT NULL,
    payment_id TEXT
)
"""


class OrderRepository:
    def __init__(self, path):
        self.conn = sqlite3.connect(path, check_same_thread=False)
        self.conn.row_factory = sqlite3.Row
        self.conn.execute(SCHEMA)

    def save(self, order):
        cur = self.conn.execute(
            "INSERT INTO orders (reference, customer_email, customer_name, items, currency, status, payment_id)"
            " VALUES (?, ?, ?, ?, ?, ?, ?)",
            (order.reference, order.customer_email, order.customer_name,
             json.dumps(order.items), order.currency, order.status, order.payment_id),
        )
        self.conn.commit()
        order.id = cur.lastrowid
        return order

    def get(self, order_id):
        from .service import Order

        row = self.conn.execute("SELECT * FROM orders WHERE id = ?", (order_id,)).fetchone()
        if row is None:
            return None
        return Order(
            id=row["id"], reference=row["reference"], customer_email=row["customer_email"],
            customer_name=row["customer_name"], items=json.loads(row["items"]),
            currency=row["currency"], status=row["status"], payment_id=row["payment_id"],
        )

    def failed_payments(self):
        rows = self.conn.execute("SELECT id FROM orders WHERE status = 'payment_failed'").fetchall()
        return [self.get(r["id"]) for r in rows]

    def mark_paid(self, order_id, payment_id):
        self.conn.execute(
            "UPDATE orders SET status = 'paid', payment_id = ? WHERE id = ?", (payment_id, order_id)
        )
        self.conn.commit()
EOF

cat > orders/cache.py <<'EOF'
import threading
import time


class TTLCache:
    """A small in-process cache with a fixed time to live per entry."""

    def __init__(self, ttl_seconds=30, max_entries=1024):
        self.ttl = ttl_seconds
        self.max_entries = max_entries
        self._data = {}
        self._lock = threading.Lock()

    def get(self, key):
        with self._lock:
            entry = self._data.get(key)
            if entry is None:
                return None
            value, expires_at = entry
            if expires_at < time.monotonic():
                del self._data[key]
                return None
            return value

    def set(self, key, value):
        with self._lock:
            if len(self._data) >= self.max_entries:
                self._data.pop(next(iter(self._data)))
            self._data[key] = (value, time.monotonic() + self.ttl)

    def invalidate(self, key):
        with self._lock:
            self._data.pop(key, None)


order_cache = TTLCache(ttl_seconds=30)
EOF

cat > orders/payments/registry.py <<'EOF'
from .handlers import BankTransferHandler, CardHandler, SandboxHandler

_HANDLERS = {
    "card": CardHandler,
    "bank_transfer": BankTransferHandler,
    "sandbox": SandboxHandler,
}


class UnknownPaymentProvider(Exception):
    pass


def get_handler(name, settings):
    try:
        handler_class = _HANDLERS[name]
    except KeyError:
        raise UnknownPaymentProvider(name) from None
    return handler_class(settings)
EOF

cat > orders/payments/handlers.py <<'EOF'
import os
import uuid
from dataclasses import dataclass


@dataclass
class Authorization:
    id: str
    approved: bool
    reason: str = ""


@dataclass
class Payment:
    id: str
    amount_cents: int


class CardHandler:
    """Card payments through the acquirer's gateway client."""

    def __init__(self, settings):
        from gateway_client import GatewayClient

        self.client = GatewayClient(api_key=os.environ["ORDERS_CARD_GATEWAY_KEY"])

    def authorize(self, amount_cents, currency, reference):
        result = self.client.authorize(amount=amount_cents, currency=currency, reference=reference)
        return Authorization(id=result["id"], approved=result["status"] == "approved",
                             reason=result.get("decline_reason", ""))

    def capture(self, authorization_id):
        result = self.client.capture(authorization_id)
        return Payment(id=result["id"], amount_cents=result["amount"])


class BankTransferHandler:
    """Bank transfer: authorization reserves a transfer reference, capture is deferred."""

    def __init__(self, settings):
        self.settings = settings

    def authorize(self, amount_cents, currency, reference):
        return Authorization(id=f"bt-{reference}", approved=True)

    def capture(self, authorization_id):
        return Payment(id=authorization_id, amount_cents=0)


class SandboxHandler:
    """Approves everything; for local development."""

    def __init__(self, settings):
        pass

    def authorize(self, amount_cents, currency, reference):
        return Authorization(id=f"sbx-{uuid.uuid4().hex[:8]}", approved=True)

    def capture(self, authorization_id):
        return Payment(id=authorization_id, amount_cents=0)
EOF

cat > orders/payments/charging.py <<'EOF'
class PaymentDeclined(Exception):
    pass


def charge(handler, amount_cents, currency, reference):
    """Authorize and capture one payment through the given handler."""
    if amount_cents <= 0:
        raise ValueError("amount must be positive")
    authorization = handler.authorize(amount_cents, currency, reference)
    if not authorization.approved:
        raise PaymentDeclined(authorization.reason or "declined")
    return handler.capture(authorization.id)
EOF

cat > orders/jobs.py <<'EOF'
"""Scheduled jobs, run by cron with `python -m orders.jobs`."""

import logging

from .config import load_settings
from .payments.charging import PaymentDeclined, charge
from .payments.registry import get_handler
from .repository import OrderRepository

log = logging.getLogger(__name__)


def retry_failed_payments(settings, repository):
    handler = get_handler(settings.payment_provider, settings)
    for order in repository.failed_payments():
        try:
            payment = charge(handler, order.total_cents, order.currency, order.reference)
        except PaymentDeclined as exc:
            log.info("order %s still declined: %s", order.id, exc)
            continue
        repository.mark_paid(order.id, payment.id)


if __name__ == "__main__":
    settings = load_settings()
    retry_failed_payments(settings, OrderRepository(settings.database_path))
EOF

cat > orders/notifications.py <<'EOF'
import logging
import smtplib
import time
from email.message import EmailMessage

log = logging.getLogger(__name__)

MAX_RETRIES = 3
RETRY_DELAY_SECONDS = 2

CONFIRMATION_TEMPLATE = """\
<html>
  <body style="font-family: Arial, sans-serif">
    <img src="{logo}" width="120" onerror="this.style.display='none'">
    <h2>Thanks for your order, {name}!</h2>
    <p>Order <b>{reference}</b>, total {total}</p>
    <p id="status">Status: {status}</p>
    <script>document.getElementById('status').innerText += ' (updated just now)';</script>
    <p><a href="{order_link}">View your order</a></p>
  </body>
</html>
"""


class MailDeliveryError(Exception):
    pass


class SmtpMailer:
    def __init__(self, settings):
        self.host = settings.mail_host
        self.port = settings.mail_port
        self.sender = settings.mail_sender

    def send(self, to, subject, html):
        message = EmailMessage()
        message["From"] = self.sender
        message["To"] = to
        message["Subject"] = subject
        message.set_content(html, subtype="html")
        try:
            with smtplib.SMTP(self.host, self.port, timeout=10) as smtp:
                smtp.send_message(message)
        except (OSError, smtplib.SMTPException) as exc:
            raise MailDeliveryError(str(exc)) from exc


def render_confirmation(order, settings):
    return CONFIRMATION_TEMPLATE.format(
        logo=settings.logo_path,
        name=order.customer_name,
        reference=order.reference,
        total=f"{order.total_cents / 100:.2f} {order.currency}",
        status=order.status,
        order_link=f"{settings.base_url}/orders/{order.id}",
    )


class OrderNotifier:
    def __init__(self, mailer, settings):
        self.mailer = mailer
        self.settings = settings
        self.retry_count = 0

    def send_confirmation(self, order):
        """Email the order confirmation, retrying on delivery errors."""
        html = render_confirmation(order, self.settings)
        subject = f"Your order {order.reference}"
        while True:
            try:
                self.mailer.send(order.customer_email, subject, html)
                log.info("confirmation sent for order %s", order.id)
                return True
            except MailDeliveryError as exc:
                if self.retry_count >= MAX_RETRIES:
                    log.error("giving up on confirmation for order %s: %s", order.id, exc)
                    return False
                self.retry_count += 1
                time.sleep(RETRY_DELAY_SECONDS * self.retry_count)
EOF

git add -A
git commit -qm "Orders API: place orders, charge, store and email a confirmation"
