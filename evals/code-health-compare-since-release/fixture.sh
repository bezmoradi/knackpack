#!/bin/bash
# A marketplace order importer with ten months of history and a v1.4.0 tag.
# Up to the tag, every import rule went into orders/importer.py's
# import_batch(), a long function nested five deep that changed in 11 of the
# 15 commits. After the tag, one commit split it into a function per step,
# leaving import_batch a short loop. orders/refunds.py's reconcile_refunds(),
# also long and deeply nested, changed three times before the tag and never
# after. Nothing written after the tag is long or deeply nested.
# Each commit writes every file at its step: a line ending in "#@N" exists from
# step N on, and one ending in "#@N-M" from step N until step M.
set -euo pipefail
git init -q -b main
git config user.name "Tomás Reyes"
git config user.email "tomas@example.com"
now=$(date +%s)
mkdir -p orders tests

reveal() { # <step> <file>, the marked text on stdin
	awk -v k="$1" '
	match($0, / +#@[0-9]+(-[0-9]+)?$/) {
		m = substr($0, RSTART); sub(/^ +#@/, "", m); line = substr($0, 1, RSTART - 1)
		n = split(m, r, "-"); if (k + 0 >= r[1] + 0 && (n == 1 || k + 0 < r[2] + 0)) print line
		next
	}
	{ print }' > "$2"
}

put() { # <step> <first step> <text> <file>
	[ "$1" -ge "$2" ] || return 0
	printf '%s' "$3" | reveal "$1" "$4"
}

stamp() { # <days ago> <who>: set the author, committer and dates for the next git command
	ts=$((now - $1 * 86400 - 3600 * ($1 % 7)))
	case $2 in
	tomas) name="Tomás Reyes" email=tomas@example.com ;;
	aiko) name="Aiko Tanaka" email=aiko@example.com ;;
	femi) name="Femi Adeyemi" email=femi@example.com ;;
	esac
	export GIT_AUTHOR_NAME="$name" GIT_AUTHOR_EMAIL=$email GIT_COMMITTER_NAME="$name" GIT_COMMITTER_EMAIL=$email
	export GIT_AUTHOR_DATE="$ts +0000" GIT_COMMITTER_DATE="$ts +0000"
}

commit() { # <step> <days ago> <who> <message>
	if [ "$1" -lt 16 ]; then put "$1" 1 "$IMPORTER_OLD" orders/importer.py; else put "$1" 16 "$IMPORTER_NEW" orders/importer.py; fi
	put "$1" 3 "$REFUNDS" orders/refunds.py
	put "$1" 1 "$CATALOG" orders/catalog.py
	put "$1" 1 "$STORE" orders/store.py
	put "$1" 1 "$CLI" orders/cli.py
	put "$1" 1 "$TESTS" tests/test_importer.py
	put "$1" 1 "$README" README.md
	put "$1" 1 "$PYPROJECT" pyproject.toml
	git add -A
	stamp "$2" "$3"
	git commit -qm "$4"
}

IFS= read -r -d '' IMPORTER_OLD <<'PY' || true
"""Imports a marketplace's order export (CSV rows as dicts) into our order store."""

from decimal import Decimal, InvalidOperation

from orders.catalog import UnknownSku  #@4

CURRENCIES = {"EUR", "GBP", "SEK", "USD"}  #@8


class RowError(Exception):
    def __init__(self, row_number, reason):
        super().__init__(f"row {row_number}: {reason}")
        self.row_number = row_number
        self.reason = reason


def import_batch(rows, catalog, store):
    """Group rows into orders, resolve their lines and save them. Returns (saved, errors)."""
    orders = {}
    errors = []
    seen = set()  #@12
    for number, row in enumerate(rows, start=2):
        key = (row.get("order_id"), row.get("line_id"))  #@12
        if key in seen:  #@12
            continue  #@12
        seen.add(key)  #@12
        if row.get("status") == "cancelled":  #@2
            continue  #@2
        order_id = row.get("order_id", "").strip()
        if not order_id:
            errors.append(RowError(number, "no order_id"))
            continue
        currency = row.get("currency", "").upper()  #@8
        if currency not in CURRENCIES:  #@8
            errors.append(RowError(number, f"unknown currency {currency!r}"))  #@8
            continue  #@8
        try:
            quantity = int(row["quantity"])
            price = Decimal(row["unit_price"])
        except (KeyError, ValueError, InvalidOperation):
            errors.append(RowError(number, "bad quantity or unit_price"))
            continue
        order = orders.setdefault(order_id, {"id": order_id, "lines": [], "discounts": []})  #@1-8
        order = orders.setdefault(order_id, {"id": order_id, "currency": currency, "lines": [], "discounts": []})  #@8
        kind = row.get("line_type", "product")
        if kind == "product":
            sku = row.get("sku", "")  #@1-14
            sku = row.get("sku", "").strip()  #@14
            try:  #@4
                sku = catalog.our_sku(sku)  #@4
            except UnknownSku:  #@4
                errors.append(RowError(number, f"unknown SKU {sku!r}"))  #@4
                continue  #@4
            order["lines"].append({"sku": sku, "quantity": quantity, "unit_price": price})  #@1-9
            if catalog.is_bundle(sku):  #@9
                parts = catalog.bundle_parts(sku)  #@9
                for part, per_bundle in parts:  #@9
                    if catalog.stock(part) < per_bundle * quantity:  #@13
                        backordered = True  #@13
                    else:  #@13
                        backordered = False  #@13
                    order["lines"].append(  #@9
                        {"sku": part, "quantity": per_bundle * quantity, "unit_price": price / len(parts) / per_bundle}  #@9-13
                        {  #@13
                            "sku": part,  #@13
                            "quantity": per_bundle * quantity,  #@13
                            "unit_price": price / len(parts) / per_bundle,  #@13
                            "backordered": backordered,  #@13
                        }  #@13
                    )  #@9
            else:  #@9
                order["lines"].append({"sku": sku, "quantity": quantity, "unit_price": price})  #@9-13
                backordered = catalog.stock(sku) < quantity  #@13
                order["lines"].append({"sku": sku, "quantity": quantity, "unit_price": price, "backordered": backordered})  #@13
        elif kind == "discount":  #@5
            if price > 0:  #@5
                price = -price  #@5
            target = row.get("applies_to_sku")  #@5
            if target:  #@5
                try:  #@5
                    target = catalog.our_sku(target.strip())  #@5
                except UnknownSku:  #@5
                    errors.append(RowError(number, f"discount for unknown SKU {target!r}"))  #@5
                    continue  #@5
            order["discounts"].append({"sku": target or None, "amount": price * quantity})  #@5
        elif kind == "gift_wrap":  #@7
            order["lines"].append({"sku": "GIFT-WRAP", "quantity": quantity, "unit_price": price})  #@7-13
            order["lines"].append({"sku": "GIFT-WRAP", "quantity": quantity, "unit_price": price, "backordered": False})  #@13
        elif kind == "shipping":  #@11
            try:  #@11
                tax_rate = Decimal(row.get("tax_rate") or "0")  #@11
            except InvalidOperation:  #@11
                errors.append(RowError(number, "bad tax_rate"))  #@11
                continue  #@11
            order["shipping"] = price * (1 + tax_rate)  #@11
        else:
            errors.append(RowError(number, f"unknown line_type {kind!r}"))
            continue
    saved = 0
    for order in orders.values():
        if not order["lines"]:
            continue
        rejected = False  #@5
        for discount in order["discounts"]:  #@5
            if discount["sku"] is None:  #@5
                first = order["lines"][0]  #@5
                first["unit_price"] += discount["amount"] / first["quantity"]  #@5
                continue  #@5
            for line in order["lines"]:  #@5
                if line["sku"] == discount["sku"]:  #@5
                    line["unit_price"] += discount["amount"] / line["quantity"]  #@5
                    break  #@5
            else:  #@5
                errors.append(RowError(0, f"order {order['id']}: discount for {discount['sku']} matches no line"))  #@5
                rejected = True  #@5
        if rejected:  #@5
            continue  #@5
        store.save(order)
        saved += 1
    return saved, errors
PY

IFS= read -r -d '' IMPORTER_NEW <<'PY' || true
"""Imports a marketplace's order export (CSV rows as dicts) into our order store."""

from decimal import Decimal, InvalidOperation

from orders.catalog import UnknownSku

CURRENCIES = {"EUR", "GBP", "SEK", "USD"}


class RowError(Exception):
    def __init__(self, row_number, reason):
        super().__init__(f"row {row_number}: {reason}")  #@16-18
        super().__init__(f"row {row_number}: {reason}" if row_number else reason)  #@18
        self.row_number = row_number
        self.reason = reason


def parse_row(number, row):
    """Check the fields every row has; returns (order_id, currency, quantity, unit price)."""
    order_id = row.get("order_id", "").strip()
    if not order_id:
        raise RowError(number, "no order_id")
    currency = row.get("currency", "").upper()
    if currency not in CURRENCIES:
        raise RowError(number, f"unknown currency {currency!r}")
    try:
        return order_id, currency, int(row["quantity"]), Decimal(row["unit_price"])
    except (KeyError, ValueError, InvalidOperation):
        raise RowError(number, "bad quantity or unit_price") from None


def resolve_lines(number, row, catalog, quantity, price):
    """The order lines a product row becomes: the product itself, or a bundle's parts."""
    sku = row.get("sku", "").strip()
    try:
        sku = catalog.our_sku(sku)
    except UnknownSku:
        raise RowError(number, f"unknown SKU {sku!r}") from None
    if not catalog.is_bundle(sku):
        return [{"sku": sku, "quantity": quantity, "unit_price": price, "backordered": catalog.stock(sku) < quantity}]
    parts = catalog.bundle_parts(sku)
    return [
        {
            "sku": part,
            "quantity": per_bundle * quantity,
            "unit_price": price / len(parts) / per_bundle,
            "backordered": catalog.stock(part) < per_bundle * quantity,
        }
        for part, per_bundle in parts
    ]


def discount(number, row, catalog, quantity, price):
    """A discount row as {"sku", "amount"}; sku None means it applies to the whole order."""
    if price > 0:
        price = -price
    target = row.get("applies_to_sku")
    if target:
        try:
            target = catalog.our_sku(target.strip())
        except UnknownSku:
            raise RowError(number, f"discount for unknown SKU {target!r}") from None
    return {"sku": target or None, "amount": price * quantity}


def add_row(order, number, row, catalog, quantity, price):
    """Add one row to its order, by the row's line_type."""
    kind = row.get("line_type", "product")
    if kind == "product":
        order["lines"].extend(resolve_lines(number, row, catalog, quantity, price))
    elif kind == "discount":
        order["discounts"].append(discount(number, row, catalog, quantity, price))
    elif kind == "gift_wrap":
        order["lines"].append({"sku": "GIFT-WRAP", "quantity": quantity, "unit_price": price, "backordered": False})
    elif kind == "shipping":
        try:
            tax_rate = Decimal(row.get("tax_rate") or "0")
        except InvalidOperation:
            raise RowError(number, "bad tax_rate") from None
        order["shipping"] = price * (1 + tax_rate)
    else:
        raise RowError(number, f"unknown line_type {kind!r}")


def apply_discounts(order):
    """Take each discount off its line, or off the first line; returns an error for each discount that matches no line."""
    errors = []
    for d in order["discounts"]:
        lines = [line for line in order["lines"] if d["sku"] is None or line["sku"] == d["sku"]]
        if not lines:
            errors.append(RowError(0, f"order {order['id']}: discount for {d['sku']} matches no line"))
            continue
        lines[0]["unit_price"] += d["amount"] / lines[0]["quantity"]
    return errors


def import_batch(rows, catalog, store):
    """Group rows into orders, resolve their lines and save them. Returns (saved, errors)."""
    orders, errors, seen = {}, [], set()
    for number, row in enumerate(rows, start=2):
        key = (row.get("order_id"), row.get("line_id"))
        if key in seen:
            continue
        seen.add(key)
        if row.get("status") == "cancelled":
            continue
        try:
            order_id, currency, quantity, price = parse_row(number, row)
            order = orders.setdefault(order_id, {"id": order_id, "currency": currency, "lines": [], "discounts": []})
            add_row(order, number, row, catalog, quantity, price)
        except RowError as e:
            errors.append(e)
    saved = 0
    for order in orders.values():
        if not order["lines"]:
            continue
        rejected = apply_discounts(order)
        errors.extend(rejected)
        if rejected:
            continue
        store.save(order)
        saved += 1
    return saved, errors
PY

IFS= read -r -d '' REFUNDS <<'PY' || true
"""Matches the marketplace's refund report against our ledger."""

from decimal import Decimal

TOLERANCE = Decimal("0.01")


def reconcile_refunds(refunds, orders, ledger):  #@3-10
def reconcile_refunds(refunds, orders, ledger, rates=None):  #@10
    """Return (matched, problems): the refunds we can book, and why each other one can't be."""
    matched = []
    problems = []
    for refund in refunds:
        rid = refund["refund_id"]
        order = orders.get(refund["order_id"])
        if order is None:
            problems.append((rid, "unknown order"))
            continue
        amount = Decimal(refund["amount"])
        if refund.get("currency", order["currency"]) != order["currency"]:  #@10
            if not rates:  #@10
                problems.append((rid, "refund in another currency, and no exchange rates given"))  #@10
                continue  #@10
            rate = rates.get((refund["currency"], order["currency"]))  #@10
            if rate is None:  #@10
                problems.append((rid, f"no rate from {refund['currency']} to {order['currency']}"))  #@10
                continue  #@10
            amount = (amount * rate).quantize(TOLERANCE)  #@10
        paid = ledger.paid(order["id"])
        booked = ledger.refunded(order["id"])
        if booked + amount > paid + TOLERANCE:
            problems.append((rid, f"refunds would add up to more than the {paid} paid"))
            continue
        if refund.get("line_ids"):  #@6
            ok = True  #@6
            for line_id in refund["line_ids"]:  #@6
                line = next((line for line in order["lines"] if line["id"] == line_id), None)  #@6
                if line is None:  #@6
                    problems.append((rid, f"unknown line {line_id}"))  #@6
                    ok = False  #@6
                    break  #@6
                if line["refunded"]:  #@6
                    if ledger.line_refund(line_id) is None:  #@6
                        problems.append((rid, f"line {line_id} is marked refunded but the ledger has no refund for it"))  #@6
                    else:  #@6
                        problems.append((rid, f"line {line_id} was already refunded"))  #@6
                    ok = False  #@6
                    break  #@6
            if not ok:  #@6
                continue  #@6
            lines_total = sum(line["unit_price"] * line["quantity"] for line in order["lines"] if line["id"] in refund["line_ids"])  #@6
            if abs(lines_total - amount) <= TOLERANCE:  #@6
                kind = "lines"  #@6
            elif amount < lines_total:  #@6
                kind = "partial"  #@6
            else:  #@6
                problems.append((rid, f"refund of {amount} is more than its lines' {lines_total}"))  #@6
                continue  #@6
        if abs(booked + amount - paid) <= TOLERANCE:  #@3-6
        elif abs(booked + amount - paid) <= TOLERANCE:  #@6
            kind = "full"
        else:
            kind = "partial"
        matched.append({"refund_id": rid, "order_id": order["id"], "amount": amount, "kind": kind})
    return matched, problems
PY

IFS= read -r -d '' CATALOG <<'PY' || true
"""Our product catalog: the marketplace's SKUs mapped to ours, bundles, and stock."""


class UnknownSku(Exception):
    pass


class Catalog:
    def __init__(self, sku_map, bundles, stock):
        self._sku_map = sku_map  # marketplace SKU -> our SKU
        self._bundles = bundles  # our bundle SKU -> [(part SKU, how many per bundle)]
        self._stock = stock  # our SKU -> units in stock

    def our_sku(self, marketplace_sku):
        try:
            return self._sku_map[marketplace_sku]
        except KeyError:
            raise UnknownSku(marketplace_sku) from None

    def is_bundle(self, sku):
        return sku in self._bundles

    def bundle_parts(self, sku):
        return self._bundles[sku]

    def stock(self, sku):
        return self._stock.get(sku, 0)
PY

IFS= read -r -d '' STORE <<'PY' || true
"""Saves imported orders as JSON files, one per order."""

import json
from pathlib import Path


class OrderStore:
    def __init__(self, directory):
        self.directory = Path(directory)

    def save(self, order):
        if not order["id"].replace("-", "").isalnum():
            raise ValueError(f"order id {order['id']!r} can't be used as a file name")
        self.directory.mkdir(parents=True, exist_ok=True)
        path = self.directory / f"{order['id']}.json"
        path.write_text(json.dumps(order, default=str, indent=2), encoding="utf-8")
PY

IFS= read -r -d '' CLI <<'PY' || true
"""Import a marketplace order export: python3 -m orders.cli export.csv"""

import argparse
import csv
import json
import sys

from orders.catalog import Catalog
from orders.importer import import_batch
from orders.store import OrderStore


def load_catalog(path):
    with open(path, encoding="utf-8") as f:
        raw = json.load(f)
    if not isinstance(raw, dict) or not all(isinstance(raw.get(k), dict) for k in ("sku_map", "bundles", "stock")):
        sys.exit(f"{path}: needs sku_map, bundles and stock objects")
    return Catalog(raw["sku_map"], {k: [tuple(p) for p in v] for k, v in raw["bundles"].items()}, raw["stock"])


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("export")
    parser.add_argument("--catalog", default="catalog.json")
    parser.add_argument("--out", default="imported")
    parser.add_argument("--quiet", action="store_true", help="don't list rejected rows")  #@19
    args = parser.parse_args(argv)
    with open(args.export, newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    saved, errors = import_batch(rows, load_catalog(args.catalog), OrderStore(args.out))
    for e in errors:  #@1-19
        print(e, file=sys.stderr)  #@1-19
    if not args.quiet:  #@19
        for e in errors:  #@19
            print(e, file=sys.stderr)  #@19
    print(f"imported {saved} orders, {len(errors)} rows rejected")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
PY

IFS= read -r -d '' TESTS <<'PY' || true
import unittest
from decimal import Decimal  #@17

from orders.catalog import Catalog
from orders.importer import import_batch  #@1-17
from orders.importer import RowError, apply_discounts, import_batch, parse_row, resolve_lines  #@17


class MemoryStore:
    def __init__(self):
        self.orders = []

    def save(self, order):
        self.orders.append(order)


CATALOG = Catalog({"MK-1": "SKU-1", "MK-2": "SKU-2", "MK-B": "BUNDLE-1"}, {"BUNDLE-1": [("SKU-1", 1), ("SKU-2", 2)]}, {"SKU-1": 10})


def row(**fields):
    base = {"order_id": "A-1", "line_id": "1", "currency": "EUR", "quantity": "1", "unit_price": "10.00", "sku": "MK-1"}
    base.update(fields)
    return base


class ImportBatchTest(unittest.TestCase):
    def test_groups_rows_by_order(self):
        store = MemoryStore()
        saved, errors = import_batch([row(), row(line_id="2", sku="MK-2"), row(order_id="A-2")], CATALOG, store)
        self.assertEqual((saved, errors), (2, []))
        self.assertEqual(len(store.orders[0]["lines"]), 2)
  #@17
    def test_cancelled_rows_are_skipped(self):  #@17
        saved, _ = import_batch([row(status="cancelled")], CATALOG, MemoryStore())  #@17
        self.assertEqual(saved, 0)  #@17
  #@17
  #@17
class StepTest(unittest.TestCase):  #@17
    def test_unknown_currency_is_rejected(self):  #@17
        with self.assertRaises(RowError):  #@17
            parse_row(2, row(currency="XYZ"))  #@17
  #@17
    def test_bundle_becomes_its_parts(self):  #@17
        lines = resolve_lines(2, row(sku="MK-B"), CATALOG, 1, Decimal("30"))  #@17
        self.assertEqual([(line["sku"], line["quantity"]) for line in lines], [("SKU-1", 1), ("SKU-2", 2)])  #@17
  #@17
    def test_discount_that_matches_no_line_is_an_error(self):  #@17
        order = {"id": "A-1", "lines": [{"sku": "SKU-1", "quantity": 1, "unit_price": Decimal(10)}], "discounts": [{"sku": "SKU-9", "amount": Decimal(-1)}]}  #@17
        self.assertEqual(len(apply_discounts(order)), 1)  #@17


if __name__ == "__main__":
    unittest.main()
PY

IFS= read -r -d '' README <<'MD' || true
# orders

Imports the marketplace's order export into our order store.

    python3 -m orders.cli export.csv --catalog catalog.json --out imported/

## Tests

    python3 -m unittest discover -s tests
MD

IFS= read -r -d '' PYPROJECT <<'TOML' || true
[project]
name = "orders"
version = "1.0.0"  #@1-15
version = "1.4.0"  #@15
requires-python = ">=3.11"
TOML

commit 1 300 tomas "Import marketplace orders from CSV"
commit 2 288 tomas "Skip rows for cancelled orders"
commit 3 280 aiko "Reconcile refunds against the ledger"
commit 4 270 tomas "Map the marketplace's SKUs to ours"
commit 5 258 femi "Apply the marketplace's discount lines"
commit 6 249 aiko "Refunds of single lines"
commit 7 240 femi "Gift wrap is a line, not a product"
commit 8 228 tomas "Reject rows in a currency we don't take"
commit 9 215 femi "Bundles become their parts"
commit 10 203 aiko "Refunds in another currency"
commit 11 190 tomas "Shipping lines carry tax"
commit 12 176 femi "Ignore rows repeated within a batch"
commit 13 160 tomas "Mark back-ordered lines"
commit 14 140 femi "Strip whitespace from SKUs"
commit 15 125 tomas "Release 1.4.0"
stamp 125 tomas
git tag -a v1.4.0 -m "1.4.0"
commit 16 104 aiko "Split import_batch into a function per step"
commit 17 86 aiko "Tests for each import step"
commit 18 51 femi "Order-level import errors have no row number"
commit 19 15 tomas "--quiet hides the rejected rows"
