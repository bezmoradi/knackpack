#!/bin/bash
# A small Python stock-keeping service with five months of history and a clean
# working tree: nothing uncommitted to review, so the request is about the
# code base as a whole.
set -euo pipefail
git init -q -b main
git config user.name "Lucia Romano"
git config user.email "lucia@example.com"
now=$(date +%s)
mkdir -p stock tests

commit() { # <days ago> <message>
	local ts=$((now - $1 * 86400))
	git add -A
	GIT_AUTHOR_DATE="$ts +0000" GIT_COMMITTER_DATE="$ts +0000" git commit -qm "$2"
}

cat > stock/__init__.py <<'PY'
"""Stock levels per warehouse, and the moves between them."""
PY
cat > stock/ledger.py <<'PY'
"""Every change to stock is a move; levels are the sum of the moves."""

from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime


@dataclass(frozen=True)
class Move:
    sku: str
    warehouse: str
    quantity: int
    reason: str
    at: datetime


class Ledger:
    def __init__(self):
        self.moves = []

    def record(self, move):
        if move.quantity == 0:
            raise ValueError("a move must change the quantity")
        if self.level(move.sku, move.warehouse) + move.quantity < 0:
            raise ValueError(f"not enough {move.sku} in {move.warehouse}")
        self.moves.append(move)

    def level(self, sku, warehouse):
        return sum(m.quantity for m in self.moves if m.sku == sku and m.warehouse == warehouse)

    def levels(self, warehouse):
        out = defaultdict(int)
        for m in self.moves:
            if m.warehouse == warehouse:
                out[m.sku] += m.quantity
        return {sku: q for sku, q in out.items() if q}
PY
cat > tests/test_ledger.py <<'PY'
import unittest
from datetime import datetime

from stock.ledger import Ledger, Move

T = datetime(2026, 1, 5, 9, 0)


class LedgerTest(unittest.TestCase):
    def test_level_is_the_sum_of_moves(self):
        ledger = Ledger()
        ledger.record(Move("A1", "north", 10, "delivery", T))
        ledger.record(Move("A1", "north", -3, "sale", T))
        self.assertEqual(ledger.level("A1", "north"), 7)

    def test_cannot_go_negative(self):
        with self.assertRaises(ValueError):
            Ledger().record(Move("A1", "north", -1, "sale", T))


if __name__ == "__main__":
    unittest.main()
PY
cat > README.md <<'MD'
# stock

Stock levels per warehouse.

    python3 -m unittest discover -s tests
MD
commit 150 "Stock ledger"

cat > stock/transfers.py <<'PY'
"""Moving stock from one warehouse to another."""

from datetime import datetime, timezone

from stock.ledger import Move


def transfer(ledger, sku, source, target, quantity, now=None):
    """Move quantity of sku from source to target, as two moves."""
    if quantity <= 0:
        raise ValueError("transfer a positive quantity")
    if source == target:
        raise ValueError("source and target are the same warehouse")
    now = now or datetime.now(timezone.utc)
    ledger.record(Move(sku, source, -quantity, f"transfer to {target}", now))
    ledger.record(Move(sku, target, quantity, f"transfer from {source}", now))
PY
commit 121 "Transfers between warehouses"

cat > stock/reorder.py <<'PY'
"""Which SKUs to reorder, from their levels and each SKU's reorder point."""


def to_reorder(levels, points, on_order=None):
    """SKUs whose level plus what's already on order is at or below their reorder point."""
    on_order = on_order or {}
    out = []
    for sku, point in sorted(points.items()):
        if levels.get(sku, 0) + on_order.get(sku, 0) <= point:
            out.append(sku)
    return out
PY
commit 88 "Reorder report"

cat > tests/test_reorder.py <<'PY'
import unittest

from stock.reorder import to_reorder


class ReorderTest(unittest.TestCase):
    def test_counts_what_is_on_order(self):
        self.assertEqual(to_reorder({"A1": 2, "B2": 9}, {"A1": 5, "B2": 5}, {"A1": 10}), [])
        self.assertEqual(to_reorder({"A1": 2, "B2": 9}, {"A1": 5, "B2": 5}), ["A1"])


if __name__ == "__main__":
    unittest.main()
PY
commit 60 "Tests for the reorder report"

sed -i.bak 's/^    """Move quantity of sku from source to target, as two moves."""$/    """Move quantity of sku from source to target, as two moves recorded at the same time."""/' stock/transfers.py
rm stock/transfers.py.bak
commit 21 "Transfers record both moves at one time"
