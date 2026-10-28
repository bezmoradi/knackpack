#!/bin/bash
# A small orders module whose reads check the caller's tenant, committed, plus
# an uncommitted change that adds a status update without that check.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p app
cat > app/orders.py <<'PY'
"""Orders, each owned by one tenant."""

from dataclasses import dataclass


class NotFound(Exception):
    pass


@dataclass
class User:
    user_id: str
    tenant_id: str


@dataclass
class Order:
    order_id: str
    tenant_id: str
    status: str


_ORDERS: dict[str, Order] = {}


def get_order(user: User, order_id: str) -> Order:
    order = _ORDERS.get(order_id)
    # The same answer for "missing" and "not yours", so IDs can't be probed.
    if order is None or order.tenant_id != user.tenant_id:
        raise NotFound(order_id)
    return order
PY
git add -A
git commit -qm "Add orders module"
cat >> app/orders.py <<'PY'


ALLOWED_STATUSES = {"pending", "shipped", "cancelled"}


def update_order_status(user: User, order_id: str, status: str) -> Order:
    if status not in ALLOWED_STATUSES:
        raise ValueError(f"unknown status: {status}")
    order = _ORDERS.get(order_id)
    if order is None:
        raise NotFound(order_id)
    order.status = status
    return order
PY
