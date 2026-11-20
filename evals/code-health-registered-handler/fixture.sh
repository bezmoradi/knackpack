#!/bin/bash
# A payment webhook receiver with ten months of history. dispatch.py turns an
# event type such as "charge.refunded" into a module name and loads it with
# importlib, so no file imports the handler modules. Every handler but
# webhooks/handlers/dispute_closed.py has a test that imports it and a README
# line; dispute_closed.py has neither, and nothing else names it, but dispatch
# reaches it for every dispute.closed event.
# Each commit writes every file at its step: a line ending in "#@N" exists from
# step N on, and one ending in "#@N-M" from step N until step M.
set -euo pipefail
git init -q -b main
git config user.name "Ravi Menon"
git config user.email "ravi@example.com"
now=$(date +%s)
mkdir -p webhooks/handlers tests

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

commit() { # <step> <days ago> <who> <message>
	local ts=$((now - $2 * 86400 - 3600 * ($2 % 7))) name email
	case $3 in
	ravi) name="Ravi Menon" email=ravi@example.com ;;
	hana) name="Hana Novak" email=hana@example.com ;;
	luis) name="Luis Ortega" email=luis@example.com ;;
	esac
	put "$1" 1 "$INIT" webhooks/__init__.py
	put "$1" 1 "$DISPATCH" webhooks/dispatch.py
	put "$1" 1 "$LEDGER" webhooks/ledger.py
	put "$1" 1 "$SERVER" webhooks/server.py
	put "$1" 1 "$HANDLERS_INIT" webhooks/handlers/__init__.py
	put "$1" 1 "$CHARGE_SUCCEEDED" webhooks/handlers/charge_succeeded.py
	put "$1" 2 "$CHARGE_REFUNDED" webhooks/handlers/charge_refunded.py
	put "$1" 3 "$PAYOUT_PAID" webhooks/handlers/payout_paid.py
	put "$1" 5 "$DISPUTE_CREATED" webhooks/handlers/dispute_created.py
	put "$1" 9 "$DISPUTE_CLOSED" webhooks/handlers/dispute_closed.py
	put "$1" 1 "$TEST_DISPATCH" tests/test_dispatch.py
	put "$1" 2 "$TEST_REFUNDED" tests/test_charge_refunded.py
	put "$1" 3 "$TEST_PAYOUT" tests/test_payout_paid.py
	put "$1" 5 "$TEST_DISPUTE" tests/test_dispute_created.py
	put "$1" 1 "$README" README.md
	git add -A
	GIT_AUTHOR_NAME=$name GIT_AUTHOR_EMAIL=$email GIT_COMMITTER_NAME=$name GIT_COMMITTER_EMAIL=$email \
		GIT_AUTHOR_DATE="$ts +0000" GIT_COMMITTER_DATE="$ts +0000" git commit -qm "$4"
}

IFS= read -r -d '' INIT <<'PY' || true
"""Books the payment provider's webhook events in our ledger."""
PY

IFS= read -r -d '' HANDLERS_INIT <<'PY' || true
"""Event handlers."""
PY

IFS= read -r -d '' DISPATCH <<'PY' || true
"""Receives the payment provider's webhooks and hands each event to its handler.

An event of type "charge.refunded" is handled by handlers/charge_refunded.py,
which defines handle(event, ledger). An event type with no handler module is
acknowledged and ignored, so the provider stops retrying it.
"""

import hashlib
import hmac
import importlib
import json
import logging
import re
import time

log = logging.getLogger(__name__)

EVENT_TYPE = re.compile(r"^[a-z]+(\.[a-z_]+)+$")
TOLERANCE_SECONDS = 300  #@4


class Rejected(Exception):
    """The request isn't a genuine, current webhook; answer 400."""


def verify(body, header, secret, now=None):
    """Check the signature header: t=<unix time>,v1=<hex HMAC-SHA256 of "<t>.<body>">."""
    parts = dict(item.split("=", 1) for item in header.split(",") if "=" in item)
    try:
        timestamp = int(parts["t"])
        signature = parts["v1"]
    except (KeyError, ValueError):
        raise Rejected("malformed signature header") from None
    if abs((now or time.time()) - timestamp) > TOLERANCE_SECONDS:  #@4
        raise Rejected("signature timestamp is too old")  #@4
    expected = hmac.new(secret, f"{timestamp}.".encode() + body, hashlib.sha256).hexdigest()
    if not hmac.compare_digest(expected, signature):
        raise Rejected("bad signature")


def handler_for(event_type):
    """The handle function for an event type, or None when no module handles it."""
    if not EVENT_TYPE.match(event_type):
        return None
    name = f"{__package__}.handlers.{event_type.replace('.', '_')}"
    try:
        module = importlib.import_module(name)
    except ModuleNotFoundError as e:
        if e.name != name:
            raise
        return None
    return getattr(module, "handle", None)


def dispatch(body, header, secret, ledger):
    """Verify and handle one webhook, and return the HTTP status to answer with."""
    try:
        verify(body, header, secret)
        event = json.loads(body)
    except (Rejected, json.JSONDecodeError) as e:
        log.warning("rejected webhook: %s", e)
        return 400
    if ledger.seen_event(event.get("id")):  #@6
        return 200  #@6
    handle = handler_for(str(event.get("type", "")))
    if handle is None:
        log.info("no handler for %s", event.get("type"))
        return 200
    handle(event, ledger)
    ledger.mark_event(event.get("id"))  #@6
    return 200
PY

IFS= read -r -d '' LEDGER <<'PY' || true
"""Our ledger in SQLite: each booking is an account, a reference, an amount and a currency."""

import sqlite3
from decimal import Decimal


class Ledger:
    def __init__(self, path):
        self.db = sqlite3.connect(path)
        self.db.executescript(
            """
            CREATE TABLE IF NOT EXISTS bookings (account TEXT, reference TEXT, amount TEXT, currency TEXT);
            CREATE INDEX IF NOT EXISTS bookings_reference ON bookings (reference);  #@10
            CREATE TABLE IF NOT EXISTS events (id TEXT PRIMARY KEY);  #@6
            """
        )

    def book(self, account, reference, amount, currency):
        self.db.execute("INSERT INTO bookings VALUES (?, ?, ?, ?)", (account, reference, str(amount), currency))
        self.db.commit()

    def balance(self, account, currency):
        rows = self.db.execute("SELECT amount FROM bookings WHERE account = ? AND currency = ?", (account, currency))
        return sum((Decimal(a) for (a,) in rows), Decimal(0))
  #@7
    def refunded(self, reference):  #@7
        rows = self.db.execute("SELECT amount FROM bookings WHERE account = 'refunds' AND reference = ?", (reference,))  #@7
        return sum((Decimal(a) for (a,) in rows), Decimal(0))  #@7
  #@6
    def seen_event(self, event_id):  #@6
        return self.db.execute("SELECT 1 FROM events WHERE id = ?", (event_id,)).fetchone() is not None  #@6
  #@6
    def mark_event(self, event_id):  #@6
        self.db.execute("INSERT OR IGNORE INTO events VALUES (?)", (event_id,))  #@6
        self.db.commit()  #@6
PY

IFS= read -r -d '' SERVER <<'PY' || true
"""Serve POST /webhooks with the standard library's HTTP server."""

import logging
import os
from http.server import BaseHTTPRequestHandler, HTTPServer

from webhooks.dispatch import dispatch
from webhooks.ledger import Ledger

log = logging.getLogger(__name__)  #@8


class Handler(BaseHTTPRequestHandler):
    ledger = None
    secret = b""  #@14

    def do_POST(self):
        if self.path != "/webhooks":
            self.send_error(404)
            return
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        log.info("webhook request %s", self.headers.get("Request-Id", "-"))  #@8
        secret = os.environ["WEBHOOK_SECRET"].encode()  #@1-14
        status = dispatch(body, self.headers.get("Provider-Signature", ""), secret, self.ledger)  #@1-14
        status = dispatch(body, self.headers.get("Provider-Signature", ""), self.secret, self.ledger)  #@14
        self.send_response(status)
        self.end_headers()


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    secret = os.environ.get("WEBHOOK_SECRET", "")  #@14
    if not secret:  #@14
        raise SystemExit("set WEBHOOK_SECRET")  #@14
    Handler.secret = secret.encode()  #@14
    Handler.ledger = Ledger(os.environ.get("LEDGER_DB", "ledger.db"))
    HTTPServer(("127.0.0.1", 8090), Handler).serve_forever()
PY

IFS= read -r -d '' CHARGE_SUCCEEDED <<'PY' || true
"""charge.succeeded: book the customer's payment."""

from decimal import Decimal


def handle(event, ledger):
    charge = event["data"]["object"]
    currency = charge["currency"].upper()
    ledger.book(account="customer_payments", reference=charge["id"], amount=Decimal(charge["amount"]) / 100, currency=currency)
    fee = Decimal(charge.get("fee", 0)) / 100  #@12
    if fee:  #@12
        ledger.book(account="provider_fees", reference=charge["id"], amount=fee, currency=currency)  #@12
PY

IFS= read -r -d '' CHARGE_REFUNDED <<'PY' || true
"""charge.refunded: book what was refunded since the last refund event."""

from decimal import Decimal


def handle(event, ledger):
    charge = event["data"]["object"]
    currency = charge["currency"].upper()
    amount = Decimal(charge["amount_refunded"]) / 100  #@2-7
    ledger.book(account="refunds", reference=charge["id"], amount=amount, currency=currency)  #@2-7
    total = Decimal(charge["amount_refunded"]) / 100  #@7
    new = total - ledger.refunded(charge["id"])  #@7
    if new > 0:  #@7
        ledger.book(account="refunds", reference=charge["id"], amount=new, currency=currency)  #@7
PY

IFS= read -r -d '' PAYOUT_PAID <<'PY' || true
"""payout.paid: move a payout from the provider balance to our bank account."""

from decimal import Decimal


def handle(event, ledger):
    payout = event["data"]["object"]
    amount = Decimal(payout["amount"]) / 100
    currency = payout["currency"].upper()
    ledger.book(account="provider_balance", reference=payout["id"], amount=-amount, currency=currency)
    ledger.book(account="bank", reference=payout["id"], amount=amount, currency=currency)  #@3-11
    ledger.book(account=f"bank_{currency.lower()}", reference=payout["id"], amount=amount, currency=currency)  #@11
PY

IFS= read -r -d '' DISPUTE_CREATED <<'PY' || true
"""dispute.created: hold the disputed amount until the dispute closes."""

import logging  #@13
from decimal import Decimal

log = logging.getLogger(__name__)  #@13


def handle(event, ledger):
    dispute = event["data"]["object"]
    amount = Decimal(dispute["amount"]) / 100
    currency = dispute["currency"].upper()
    log.info("dispute %s opened: %s", dispute["id"], dispute.get("reason", "no reason given"))  #@13
    ledger.book(account="customer_payments", reference=dispute["id"], amount=-amount, currency=currency)
    ledger.book(account="disputes", reference=dispute["id"], amount=amount, currency=currency)
PY

IFS= read -r -d '' DISPUTE_CLOSED <<'PY' || true
"""dispute.closed: release or write off the amount held when the dispute opened."""

from decimal import Decimal


def handle(event, ledger):
    dispute = event["data"]["object"]
    amount = Decimal(dispute["amount"]) / 100
    currency = dispute["currency"].upper()
    if dispute["status"] == "won":
        ledger.book(account="disputes", reference=dispute["id"], amount=-amount, currency=currency)
        ledger.book(account="customer_payments", reference=dispute["id"], amount=amount, currency=currency)
    elif dispute["status"] == "lost":
        ledger.book(account="disputes", reference=dispute["id"], amount=-amount, currency=currency)
        ledger.book(account="dispute_losses", reference=dispute["id"], amount=amount, currency=currency)
    # Any other status, such as warning_closed, never held money, so there's nothing to release.
PY

IFS= read -r -d '' TEST_DISPATCH <<'PY' || true
import hashlib
import hmac
import json
import time
import unittest

from webhooks import dispatch

SECRET = b"whsec_local"


def signed(body, t=None):
    t = int(t or time.time())
    return f"t={t},v1=" + hmac.new(SECRET, f"{t}.".encode() + body, hashlib.sha256).hexdigest()


class FakeLedger:
    def __init__(self):
        self.bookings = []
        self.events = set()  #@6

    def book(self, **booking):
        self.bookings.append(booking)
  #@6
    def seen_event(self, event_id):  #@6
        return event_id in self.events  #@6
  #@6
    def mark_event(self, event_id):  #@6
        self.events.add(event_id)  #@6


class VerifyTest(unittest.TestCase):
    def test_accepts_a_good_signature(self):
        dispatch.verify(b"{}", signed(b"{}"), SECRET)

    def test_rejects_a_bad_signature(self):
        with self.assertRaises(dispatch.Rejected):
            dispatch.verify(b"{}", signed(b"{}").replace("v1=", "v1=0"), SECRET)
  #@4
    def test_rejects_an_old_signature(self):  #@4
        with self.assertRaises(dispatch.Rejected):  #@4
            dispatch.verify(b"{}", signed(b"{}", time.time() - 3600), SECRET)  #@4


class DispatchTest(unittest.TestCase):
    def test_books_a_charge(self):
        body = json.dumps({"id": "evt_1", "type": "charge.succeeded", "data": {"object": {"id": "ch_1", "amount": 1250, "currency": "eur"}}}).encode()
        ledger = FakeLedger()
        self.assertEqual(dispatch.dispatch(body, signed(body), SECRET, ledger), 200)
        self.assertEqual(ledger.bookings[0]["reference"], "ch_1")

    def test_acknowledges_event_types_nobody_handles(self):
        body = json.dumps({"id": "evt_2", "type": "customer.created", "data": {"object": {}}}).encode()
        self.assertEqual(dispatch.dispatch(body, signed(body), SECRET, FakeLedger()), 200)
  #@6
    def test_handles_each_event_once(self):  #@6
        body = json.dumps({"id": "evt_3", "type": "charge.succeeded", "data": {"object": {"id": "ch_3", "amount": 100, "currency": "eur"}}}).encode()  #@6
        ledger = FakeLedger()  #@6
        dispatch.dispatch(body, signed(body), SECRET, ledger)  #@6
        dispatch.dispatch(body, signed(body), SECRET, ledger)  #@6
        self.assertEqual(len(ledger.bookings), 1)  #@6


if __name__ == "__main__":
    unittest.main()
PY

IFS= read -r -d '' TEST_REFUNDED <<'PY' || true
import unittest
from decimal import Decimal

from webhooks.handlers import charge_refunded


class Ledger:
    def __init__(self, refunded=Decimal(0)):
        self.bookings = []
        self._refunded = refunded

    def book(self, **booking):
        self.bookings.append(booking)

    def refunded(self, reference):
        return self._refunded


def event(amount_refunded):
    return {"data": {"object": {"id": "ch_1", "currency": "eur", "amount_refunded": amount_refunded}}}


class ChargeRefundedTest(unittest.TestCase):
    def test_books_the_refund(self):
        ledger = Ledger()
        charge_refunded.handle(event(500), ledger)
        self.assertEqual(ledger.bookings[0]["amount"], Decimal("5"))
  #@7
    def test_books_only_the_new_part_of_a_second_refund(self):  #@7
        ledger = Ledger(refunded=Decimal("5"))  #@7
        charge_refunded.handle(event(800), ledger)  #@7
        self.assertEqual(ledger.bookings[0]["amount"], Decimal("3"))  #@7


if __name__ == "__main__":
    unittest.main()
PY

IFS= read -r -d '' TEST_PAYOUT <<'PY' || true
import unittest
from decimal import Decimal

from webhooks.handlers import payout_paid


class Ledger:
    def __init__(self):
        self.bookings = []

    def book(self, **booking):
        self.bookings.append(booking)


class PayoutPaidTest(unittest.TestCase):
    def test_moves_the_payout_to_the_bank(self):
        ledger = Ledger()
        payout_paid.handle({"data": {"object": {"id": "po_1", "amount": 10000, "currency": "eur"}}}, ledger)
        self.assertEqual(sum(b["amount"] for b in ledger.bookings), Decimal(0))
        self.assertEqual(len(ledger.bookings), 2)


if __name__ == "__main__":
    unittest.main()
PY

IFS= read -r -d '' TEST_DISPUTE <<'PY' || true
import unittest
from decimal import Decimal

from webhooks.handlers import dispute_created


class Ledger:
    def __init__(self):
        self.bookings = []

    def book(self, **booking):
        self.bookings.append(booking)


class DisputeCreatedTest(unittest.TestCase):
    def test_holds_the_disputed_amount(self):
        ledger = Ledger()
        dispute_created.handle({"data": {"object": {"id": "dp_1", "amount": 2500, "currency": "eur"}}}, ledger)
        held = [b for b in ledger.bookings if b["account"] == "disputes"]
        self.assertEqual(held[0]["amount"], Decimal("25"))


if __name__ == "__main__":
    unittest.main()
PY

IFS= read -r -d '' README <<'MD' || true
# webhooks

Books the payment provider's webhook events in our ledger. Events we handle:

- `charge.succeeded`: the customer's payment
- `charge.refunded`: what was refunded since the last refund event  #@2
- `payout.paid`: money moving from the provider to our bank  #@3
- `dispute.created`: the disputed amount is held  #@5

## Running it

    python3 -m unittest discover -s tests
    WEBHOOK_SECRET=... python3 -m webhooks.server
MD

commit 1 310 ravi "Receive provider webhooks and book charges"
commit 2 296 ravi "Book refunds"
commit 3 281 hana "Book payouts"
commit 4 266 ravi "Reject signatures older than five minutes"
commit 5 250 hana "Hold the disputed amount when a dispute opens"
commit 6 233 luis "Handle each event once"
commit 7 215 ravi "Refunds book only the newly refunded amount"
commit 8 196 luis "Log the provider's request id"
commit 9 180 luis "Release or write off held amounts when a dispute closes"
commit 10 160 hana "Index bookings by reference"
commit 11 131 hana "Book payouts to the bank account for their currency"
commit 12 99 ravi "Book the provider's fee on each charge"
commit 13 64 hana "Log why a dispute was opened"
commit 14 28 luis "Read the webhook secret once, and refuse to start without it"
