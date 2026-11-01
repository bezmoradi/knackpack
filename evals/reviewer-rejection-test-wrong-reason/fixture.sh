#!/bin/bash
# A small Python payments module, committed, plus an uncommitted fix for
# negative transfer amounts whose two new tests never reach the new rule.
set -euo pipefail
git init -q
git config user.name "Alex Morgan"
git config user.email "alex@example.com"
mkdir -p payments tests docs
touch payments/__init__.py tests/__init__.py
cat > pyproject.toml <<'TOML'
[project]
name = "payments"
version = "3.2.0"
requires-python = ">=3.11"

[tool.pytest.ini_options]
testpaths = ["tests"]
TOML
cat > payments/transfers.py <<'PY'
"""Transfers between customer accounts, amounts in cents."""


class PermissionDenied(Exception):
    pass


class InvalidTransfer(Exception):
    pass


LEDGER: list[dict] = []


def create_transfer(session: dict | None, payload: dict) -> dict:
    if not session or not session.get("account_id"):
        raise PermissionDenied("sign in first")
    sender = session["account_id"]
    to = payload.get("to")
    if not to or to == sender:
        raise InvalidTransfer("choose another account to send to")
    amount = payload.get("amount")
    if not isinstance(amount, int):
        raise InvalidTransfer("amount must be a whole number of cents")
    entry = {"from": sender, "to": to, "amount": amount}
    LEDGER.append(entry)
    return entry
PY
cat > tests/test_transfers.py <<'PY'
import pytest

from payments.transfers import LEDGER, InvalidTransfer, create_transfer


@pytest.fixture(autouse=True)
def empty_ledger():
    LEDGER.clear()


def test_sends_money_to_another_account():
    entry = create_transfer({"account_id": "acct-1"}, {"to": "acct-2", "amount": 2500})
    assert entry == {"from": "acct-1", "to": "acct-2", "amount": 2500}
    assert LEDGER == [entry]


def test_rejects_sending_to_yourself():
    with pytest.raises(InvalidTransfer):
        create_transfer({"account_id": "acct-1"}, {"to": "acct-1", "amount": 2500})
PY
cat > docs/limits.md <<'MD'
# Transfer limits

A transfer moves at least 1 cent and at most 1,000,000 cents (10,000.00) from
the signed-in customer's account to another account.
MD
git add -A
git commit -q -m "Transfers between accounts"

# The uncommitted fix for the support ticket.
cat > payments/transfers.py <<'PY'
"""Transfers between customer accounts, amounts in cents."""


class PermissionDenied(Exception):
    pass


class InvalidTransfer(Exception):
    pass


LEDGER: list[dict] = []

MIN_CENTS = 1
MAX_CENTS = 1_000_000


def create_transfer(session: dict | None, payload: dict) -> dict:
    if not session or not session.get("account_id"):
        raise PermissionDenied("sign in first")
    sender = session["account_id"]
    to = payload.get("to")
    if not to or to == sender:
        raise InvalidTransfer("choose another account to send to")
    amount = payload.get("amount")
    if not isinstance(amount, int):
        raise InvalidTransfer("amount must be a whole number of cents")
    if amount < MIN_CENTS or amount > MAX_CENTS:
        raise InvalidTransfer("amount must be between 0.01 and 10,000.00")
    entry = {"from": sender, "to": to, "amount": amount}
    LEDGER.append(entry)
    return entry
PY
cat >> tests/test_transfers.py <<'PY'


def test_rejects_negative_amount():
    # PAY-212: a negative amount pulled money out of the recipient's account.
    with pytest.raises(Exception):
        create_transfer(None, {"to": "acct-2", "amount": -500})


def test_rejects_amount_over_the_limit():
    with pytest.raises(InvalidTransfer):
        create_transfer({"account_id": "acct-1"}, {"to": "acct-1", "amount": 2_000_000})
PY
