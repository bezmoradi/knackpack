#!/bin/bash
# A billing package: gateway.py talks to the card provider over HTTP, and
# charges.py imports charge_card from it to bill a customer and record the
# charge. The change adds a unit test for bill_customer that patches the call.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p billing tests

cat > pyproject.toml <<'TOML'
[project]
name = "billing"
version = "2.1.0"
requires-python = ">=3.10"
dependencies = []
TOML

cat > billing/__init__.py <<'PY'
"""Billing: charge cards and record the resulting charges."""
PY

cat > billing/gateway.py <<'PY'
"""Thin client for the card payment provider."""

from __future__ import annotations

import json
import urllib.request
from dataclasses import dataclass

API_URL = "https://payments.example.com/v1/charges"


@dataclass(frozen=True)
class Charge:
    charge_id: str
    cents: int


def charge_card(token: str, cents: int) -> Charge:
    payload = json.dumps({"token": token, "amount": cents}).encode()
    request = urllib.request.Request(
        API_URL,
        data=payload,
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(request, timeout=10) as response:
        body = json.load(response)
    return Charge(charge_id=body["id"], cents=cents)
PY

cat > billing/charges.py <<'PY'
"""Billing a customer and recording the charge it produced."""

from __future__ import annotations

from dataclasses import dataclass, field

from billing.gateway import Charge, charge_card


@dataclass
class Customer:
    customer_id: str
    card_token: str
    charges: list = field(default_factory=list)


def bill_customer(customer: Customer, cents: int) -> Charge:
    charge = charge_card(customer.card_token, cents)
    customer.charges.append(charge.charge_id)
    return charge
PY

cat > README.md <<'MD'
# billing

`charge_card` in `billing.gateway` calls the card provider. `bill_customer` in
`billing.charges` charges a customer and records the returned charge id.
MD

git add -A
git commit -qm "Add the payment gateway client and customer billing"

cat > tests/test_charges.py <<'PY'
import unittest
from unittest.mock import patch

from billing.charges import Customer, bill_customer
from billing.gateway import Charge


class BillCustomerTest(unittest.TestCase):
    @patch("billing.gateway.charge_card")
    def test_records_charge_id(self, mock_charge_card):
        mock_charge_card.return_value = Charge(charge_id="ch_test_123", cents=500)
        customer = Customer(customer_id="cus_1", card_token="tok_visa")

        charge = bill_customer(customer, 500)

        self.assertEqual(charge.charge_id, "ch_test_123")
        self.assertEqual(customer.charges, ["ch_test_123"])


if __name__ == "__main__":
    unittest.main()
PY
