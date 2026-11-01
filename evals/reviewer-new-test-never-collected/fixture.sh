#!/bin/bash
# A small Python billing library with a pytest suite, committed, plus an
# uncommitted fix for a proration rounding bug and its regression test.
set -euo pipefail
git init -q
git config user.name "Alex Morgan"
git config user.email "alex@example.com"
mkdir -p billing tests
touch billing/__init__.py
cat > pyproject.toml <<'TOML'
[project]
name = "billing"
version = "1.6.2"
requires-python = ">=3.10"

[tool.pytest.ini_options]
testpaths = ["tests"]
python_files = ["test_*.py"]
TOML
cat > billing/proration.py <<'PY'
"""Prorate a plan change over the days left in the billing period."""


def prorate(amount_cents: int, days_left: int, days_in_period: int) -> int:
    if not 0 <= days_left <= days_in_period or days_in_period <= 0:
        raise ValueError("days out of range")
    return round(amount_cents * days_left / days_in_period)
PY
cat > tests/test_proration.py <<'PY'
import pytest

from billing.proration import prorate


def test_full_period():
    assert prorate(3000, 30, 30) == 3000


def test_no_days_left():
    assert prorate(3000, 0, 30) == 0


def test_rejects_bad_days():
    with pytest.raises(ValueError):
        prorate(3000, 31, 30)
PY
git add -A
git commit -q -m "Proration with tests"

# The uncommitted change: fix half-cent rounding (round() rounds 0.5 to the
# even cent, so some customers were charged a cent less) and add a test.
cat > billing/proration.py <<'PY'
"""Prorate a plan change over the days left in the billing period."""

from decimal import ROUND_HALF_UP, Decimal


def prorate(amount_cents: int, days_left: int, days_in_period: int) -> int:
    if not 0 <= days_left <= days_in_period or days_in_period <= 0:
        raise ValueError("days out of range")
    exact = Decimal(amount_cents) * days_left / days_in_period
    # Half a cent rounds up, as the pricing page promises; round() would round
    # it to the even cent.
    return int(exact.quantize(Decimal(1), rounding=ROUND_HALF_UP))
PY
cat > tests/proration_rounding_test.py <<'PY'
from billing.proration import prorate


def test_half_cent_rounds_up():
    # 25 * 3 / 30 = 2.5 cents: must round up to 3, not to the even 2.
    assert prorate(25, 3, 30) == 3


def test_another_half_cent_rounds_up():
    # 35 * 3 / 30 = 3.5 cents: round() gives 4 here too, so this one passed before.
    assert prorate(35, 3, 30) == 4
PY
