#!/bin/bash
# An orders module, committed, plus an uncommitted list_orders that filters by
# tenant correctly but sorts oldest first.
set -euo pipefail
git init -q
git config user.name "Jordan Lee"
git config user.email "jordan@example.com"
mkdir -p app
cat > app/orders.py <<'PY'
"""Orders, each owned by one tenant."""

from dataclasses import dataclass
from datetime import datetime


@dataclass
class User:
    user_id: str
    tenant_id: str


@dataclass
class Order:
    order_id: str
    tenant_id: str
    created_at: datetime


_ORDERS: dict[str, Order] = {}
PY
git add -A
git commit -qm "Add orders module"
cat >> app/orders.py <<'PY'


def list_orders(user: User) -> list[Order]:
    mine = [o for o in _ORDERS.values() if o.tenant_id == user.tenant_id]
    return sorted(mine, key=lambda o: o.created_at)
PY
