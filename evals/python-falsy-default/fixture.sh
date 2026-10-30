#!/bin/bash
# A small pricing package that loads per-customer settings and totals orders,
# committed with its pricing rules, plus an uncommitted change that applies
# each customer's discount at checkout.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p pricing docs data
touch pricing/__init__.py
cat > pyproject.toml <<'TOML'
[project]
name = "pricing"
version = "2.3.0"
requires-python = ">=3.11"
dependencies = []
TOML
cat > pricing/customers.py <<'PY'
"""Per-customer pricing settings, loaded from data/customers.json."""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path

DEFAULT_DISCOUNT_PCT = 10
MAX_DISCOUNT_PCT = 50


@dataclass(frozen=True)
class CustomerSettings:
    customer_id: str
    # None when the account has no discount configured.
    discount_pct: int | None


def parse_customer(row: dict) -> CustomerSettings:
    pct = row.get("discount_pct")
    if pct is not None:
        if not isinstance(pct, int) or isinstance(pct, bool):
            raise ValueError(f"{row['customer_id']}: discount_pct must be an integer")
        if not 0 <= pct <= MAX_DISCOUNT_PCT:
            raise ValueError(f"{row['customer_id']}: discount_pct out of range: {pct}")
    return CustomerSettings(customer_id=row["customer_id"], discount_pct=pct)


def load_customers(path: Path = Path("data/customers.json")) -> dict[str, CustomerSettings]:
    rows = json.loads(path.read_text())
    return {row["customer_id"]: parse_customer(row) for row in rows}
PY
cat > pricing/orders.py <<'PY'
"""Orders as checkout sees them. Amounts are integer cents."""

from dataclasses import dataclass


@dataclass(frozen=True)
class Line:
    sku: str
    unit_cents: int
    quantity: int


@dataclass(frozen=True)
class Order:
    order_id: str
    customer_id: str
    lines: tuple[Line, ...]

    @property
    def subtotal_cents(self) -> int:
        return sum(line.unit_cents * line.quantity for line in self.lines)
PY
cat > pricing/checkout.py <<'PY'
"""Order totals."""

from pricing.customers import CustomerSettings
from pricing.orders import Order


def order_total_cents(order: Order, customer: CustomerSettings) -> int:
    return order.subtotal_cents
PY
cat > docs/pricing.md <<'MD'
# Pricing rules

Amounts are integer cents. A discount is rounded down to whole cents, so
rounding never gives away more than the configured percentage.

## Customer discounts

Each customer in `data/customers.json` may set `discount_pct`:

| Value             | Meaning                                                  |
|-------------------|----------------------------------------------------------|
| missing or `null` | Not configured: the default discount of 10% applies.     |
| `0`               | The customer must get no discount. Used for accounts on  |
|                   | contract or net pricing, where any discount breaks the   |
|                   | agreed price.                                            |
| `1` to `50`       | That percentage off the order subtotal.                  |
MD
cat > data/customers.json <<'JSON'
[
  {"customer_id": "c-1001", "discount_pct": null},
  {"customer_id": "c-1002", "discount_pct": 15},
  {"customer_id": "c-1003", "discount_pct": 0},
  {"customer_id": "c-1004"}
]
JSON
git add -A
git commit -qm "Load customer pricing settings"
cat > pricing/discounts.py <<'PY'
"""Customer discounts, as described in docs/pricing.md."""

from pricing.customers import DEFAULT_DISCOUNT_PCT, CustomerSettings
from pricing.orders import Order


def apply_discount(order: Order, customer: CustomerSettings) -> int:
    """Return the order subtotal in cents after the customer's discount."""
    pct = customer.discount_pct or DEFAULT_DISCOUNT_PCT
    # Floor division rounds the discount down to whole cents.
    discount = order.subtotal_cents * pct // 100
    return order.subtotal_cents - discount
PY
cat > pricing/checkout.py <<'PY'
"""Order totals."""

from pricing.customers import CustomerSettings
from pricing.discounts import apply_discount
from pricing.orders import Order


def order_total_cents(order: Order, customer: CustomerSettings) -> int:
    return apply_discount(order, customer)
PY
