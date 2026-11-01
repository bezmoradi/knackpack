#!/bin/bash
# A small Python order service with a nightly cleanup job, committed, plus an
# uncommitted change that lets support put a paid order on hold.
set -euo pipefail
git init -q
git config user.name "Alex Morgan"
git config user.email "alex@example.com"
mkdir -p shop jobs docs
touch shop/__init__.py jobs/__init__.py
cat > pyproject.toml <<'TOML'
[project]
name = "shop"
version = "2.8.0"
requires-python = ">=3.11"
TOML
cat > shop/models.py <<'PY'
from dataclasses import dataclass
from datetime import datetime
from enum import Enum


class Status(str, Enum):
    PENDING = "pending"      # checkout started, not paid
    PAID = "paid"
    SHIPPED = "shipped"
    CANCELLED = "cancelled"  # abandoned or cancelled before payment


@dataclass
class Order:
    order_id: str
    status: Status
    updated_at: datetime
    note: str = ""
PY
cat > shop/store.py <<'PY'
from datetime import datetime, timedelta

from shop.models import Order, Status


class OrderStore:
    def __init__(self, db) -> None:
        self.db = db

    def get(self, order_id: str) -> Order:
        return self.db.load_order(order_id)

    def save(self, order: Order) -> None:
        self.db.save_order(order)

    def untouched_since(self, days: int) -> list[Order]:
        cutoff = datetime.utcnow() - timedelta(days=days)
        return self.db.orders_updated_before(cutoff)

    def delete(self, order_id: str) -> None:
        self.db.delete_order(order_id)
PY
cat > jobs/purge_abandoned.py <<'PY'
"""Nightly: delete checkouts nobody finished, so the orders table stays small.

Anything that isn't a real order (paid or shipped) and hasn't been touched for
30 days is an abandoned checkout.
"""

from shop.models import Status
from shop.store import OrderStore

KEEP = {Status.PAID, Status.SHIPPED}


def run(store: OrderStore) -> int:
    deleted = 0
    for order in store.untouched_since(days=30):
        if order.status not in KEEP:
            store.delete(order.order_id)
            deleted += 1
    return deleted
PY
cat > shop/support.py <<'PY'
from datetime import datetime

from shop.models import Status
from shop.store import OrderStore


def cancel_unpaid(store: OrderStore, order_id: str) -> None:
    order = store.get(order_id)
    if order.status is not Status.PENDING:
        raise ValueError("only unpaid orders can be cancelled here")
    order.status = Status.CANCELLED
    order.updated_at = datetime.utcnow()
    store.save(order)
PY
git add -A
git commit -q -m "Orders, support actions and nightly cleanup"

# The uncommitted change: support can hold a paid order while they check it.
cat > shop/models.py <<'PY'
from dataclasses import dataclass
from datetime import datetime
from enum import Enum


class Status(str, Enum):
    PENDING = "pending"      # checkout started, not paid
    PAID = "paid"
    ON_HOLD = "on_hold"      # paid, paused by support (fraud or address check)
    SHIPPED = "shipped"
    CANCELLED = "cancelled"  # abandoned or cancelled before payment


@dataclass
class Order:
    order_id: str
    status: Status
    updated_at: datetime
    note: str = ""
PY
cat >> shop/support.py <<'PY'


def hold(store: OrderStore, order_id: str, reason: str) -> None:
    """Pause a paid order while support checks it; release() resumes it."""
    order = store.get(order_id)
    if order.status is not Status.PAID:
        raise ValueError("only paid orders can be held")
    order.status = Status.ON_HOLD
    order.note = reason
    order.updated_at = datetime.utcnow()
    store.save(order)


def release(store: OrderStore, order_id: str) -> None:
    order = store.get(order_id)
    if order.status is not Status.ON_HOLD:
        raise ValueError("order is not on hold")
    order.status = Status.PAID
    order.updated_at = datetime.utcnow()
    store.save(order)
PY
cat > docs/support.md <<'MD'
# Support actions

- **Hold** a paid order while you check it for fraud or a bad address. Checks
  can take weeks when the bank or the customer is slow to answer. **Release**
  it to resume fulfillment.
- **Cancel** an unpaid order.
MD
