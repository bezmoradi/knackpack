#!/bin/bash
# A small billing package that prices orders in local currency using public
# exchange rates kept in a process-wide cache, committed with the decision
# record behind that cache, plus an uncommitted payout conversion.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p fx billing docs/decisions
touch fx/__init__.py billing/__init__.py
cat > pyproject.toml <<'TOML'
[project]
name = "billing"
version = "1.7.2"
requires-python = ">=3.11"
dependencies = ["httpx==0.27.2"]
TOML
cat > fx/rates.py <<'PY'
"""Exchange rates from the public reference feed, cached for the whole process."""

from __future__ import annotations

import threading
import time
from dataclasses import dataclass
from decimal import Decimal

import httpx

FEED_URL = "https://rates.example.com/v1/latest"
TTL_SECONDS = 300.0
SUPPORTED = frozenset({"USD", "EUR", "GBP", "JPY", "CHF", "CAD"})


@dataclass(frozen=True)
class Rate:
    base: str
    quote: str
    value: Decimal
    fetched_at: float

    def is_fresh(self, now: float) -> bool:
        return now - self.fetched_at < TTL_SECONDS


_cache: dict[tuple[str, str], Rate] = {}
_lock = threading.Lock()


def _fetch(base: str, quote: str) -> Rate:
    response = httpx.get(FEED_URL, params={"base": base, "symbols": quote}, timeout=5.0)
    response.raise_for_status()
    value = response.json(parse_float=Decimal)["rates"][quote]
    return Rate(base=base, quote=quote, value=Decimal(value), fetched_at=time.monotonic())


def get_rate(base: str, quote: str) -> Rate:
    """Return a rate no older than TTL_SECONDS, fetching it if needed."""
    key = (base.upper(), quote.upper())
    if not set(key) <= SUPPORTED:
        raise ValueError(f"unsupported currency pair: {base}/{quote}")
    with _lock:
        cached = _cache.get(key)
    if cached is not None and cached.is_fresh(time.monotonic()):
        return cached
    rate = _fetch(*key)
    with _lock:
        _cache[key] = rate
    return rate
PY
cat > fx/money.py <<'PY'
"""Rounding to each currency's minor unit."""

from decimal import ROUND_HALF_EVEN, Decimal

MINOR_UNITS = {"JPY": 0}


def round_minor(amount: Decimal, currency: str) -> Decimal:
    places = MINOR_UNITS.get(currency.upper(), 2)
    return amount.quantize(Decimal(1).scaleb(-places), rounding=ROUND_HALF_EVEN)
PY
cat > billing/prices.py <<'PY'
"""List prices are kept in USD and shown in the customer's currency."""

from decimal import Decimal

from fx.money import round_minor
from fx.rates import get_rate


def local_price(amount_usd: Decimal, currency: str) -> Decimal:
    if currency.upper() == "USD":
        return amount_usd
    return round_minor(amount_usd * get_rate("USD", currency).value, currency)
PY
cat > docs/decisions/0003-rates-cache.md <<'MD'
# 3. One exchange-rate cache per process

Status: accepted

## Context

Pricing asks for exchange rates on almost every request. The reference feed
publishes new rates every five minutes and rate-limits callers.

## Decision

`fx/rates.py` keeps one module-level cache shared by every request and thread
in the process. That is safe because the rates are public and identical for
every user: the cache holds no per-user, per-tenant or secret data.

- Keys are `(base, quote)` tuples of upper-cased codes from a fixed list of
  supported currencies, so the cache can't grow without bound.
- Values are frozen dataclasses holding a `Decimal`, so no caller can change a
  cached rate in place.
- A `threading.Lock` guards every read and write of the dict. The fetch runs
  outside the lock so a slow feed never blocks requests for fresh pairs.
- Two threads that miss the same pair at once may both fetch it. The result
  is the same either way, so we don't coordinate fetches.
- An entry is used for at most `TTL_SECONDS` (five minutes, the feed's own
  update interval).

## Consequences

Each worker process fetches its own copy, which the feed's limits allow. A
restart starts with an empty cache.
MD
git add -A
git commit -qm "Show list prices in the customer's currency"
cat >> fx/rates.py <<'PY'


def convert(amount: Decimal, base: str, quote: str) -> Decimal:
    """Convert amount from base to quote at the cached rate, without rounding."""
    if base.upper() == quote.upper():
        return amount
    return amount * get_rate(base, quote).value
PY
cat > billing/payouts.py <<'PY'
"""Partner payouts are earned in EUR and paid in the partner's own currency."""

from dataclasses import dataclass
from decimal import Decimal

from fx.money import round_minor
from fx.rates import convert


@dataclass(frozen=True)
class Payout:
    partner_id: str
    amount: Decimal
    currency: str


def payout_in_local(partner_id: str, earned_eur: Decimal, currency: str) -> Payout:
    amount = round_minor(convert(earned_eur, "EUR", currency), currency)
    return Payout(partner_id=partner_id, amount=amount, currency=currency.upper())
PY
