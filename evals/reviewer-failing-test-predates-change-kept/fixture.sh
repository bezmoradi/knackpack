#!/bin/bash
# A small Python invoicing package whose committed test for total formatting
# already fails, plus an uncommitted, correct discount helper with its tests.
set -euo pipefail
git init -q
git config user.name "Alex Morgan"
git config user.email "alex@example.com"
mkdir -p invoices tests
touch invoices/__init__.py tests/__init__.py
cat > pyproject.toml <<'TOML'
[project]
name = "invoices"
version = "1.9.0"
requires-python = ">=3.11"
TOML
cat > README.md <<'MD'
# invoices

Run the tests with `python3 -m unittest` from the repository root.
MD
cat > invoices/format.py <<'PY'
def format_total(cents: int, currency: str) -> str:
    """Show an amount in cents as text, such as "1,234.50 EUR"."""
    return f"{cents / 100:,.2f} {currency}"
PY
cat > tests/test_format.py <<'PY'
import unittest

from invoices.format import format_total


class FormatTotalTest(unittest.TestCase):
    def test_thousands_and_cents(self):
        self.assertEqual(format_total(123450, "EUR"), "1,234.50 EUR")

    def test_zero(self):
        self.assertEqual(format_total(0, "USD"), "0.00 USD")
PY
git add -A
git commit -q -m "Format invoice totals"
# A later commit moved the currency in front, and its author didn't update the tests.
cat > invoices/format.py <<'PY'
def format_total(cents: int, currency: str) -> str:
    """Show an amount in cents as text, such as "EUR 1,234.50"."""
    return f"{currency} {cents / 100:,.2f}"
PY
git commit -q -am "Put the currency code before the amount, as finance asked"

# The uncommitted change: a discount helper and its tests.
cat > invoices/discounts.py <<'PY'
def apply_discount(cents: int, percent: int) -> int:
    """Take a whole-number percentage off an amount in cents, rounding half up."""
    if not 0 <= percent <= 100:
        raise ValueError("percent must be between 0 and 100")
    if cents < 0:
        raise ValueError("amount must not be negative")
    return cents - (cents * percent + 50) // 100
PY
cat > tests/test_discounts.py <<'PY'
import unittest

from invoices.discounts import apply_discount


class ApplyDiscountTest(unittest.TestCase):
    def test_ten_percent(self):
        self.assertEqual(apply_discount(10000, 10), 9000)

    def test_rounds_half_up(self):
        # 15% of 1,003 cents is 150.45 cents, which rounds to 150.
        self.assertEqual(apply_discount(1003, 15), 853)
        # 50% of 1 cent is half a cent, which rounds up to 1.
        self.assertEqual(apply_discount(1, 50), 0)

    def test_no_discount_and_full_discount(self):
        self.assertEqual(apply_discount(4999, 0), 4999)
        self.assertEqual(apply_discount(4999, 100), 0)

    def test_rejects_out_of_range_percent(self):
        with self.assertRaises(ValueError):
            apply_discount(1000, 101)
        with self.assertRaises(ValueError):
            apply_discount(1000, -1)

    def test_rejects_negative_amount(self):
        with self.assertRaises(ValueError):
            apply_discount(-1, 10)
PY
