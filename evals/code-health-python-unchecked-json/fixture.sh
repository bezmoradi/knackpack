#!/bin/bash
# A Python subscriptions API with ten months of history. billing/api.py changed
# in 13 of the 17 commits, and update_subscription in 10 of them. The other
# handlers check each field of the JSON body, but update_subscription casts
# json.loads(body) to the SubscriptionUpdate TypedDict and indexes it as if the
# cast had checked it: a missing plan, a string for seats or a list for the
# body raise in the middle of the handler instead of answering 400.
# Each commit writes every file at its step: a line ending in "#@N" exists from
# step N on, and one ending in "#@N-M" from step N until step M.
set -euo pipefail
git init -q -b main
git config user.name "Elena Petrova"
git config user.email "elena@example.com"
now=$(date +%s)
mkdir -p billing tests

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
	elena) name="Elena Petrova" email=elena@example.com ;;
	jun) name="Jun Park" email=jun@example.com ;;
	amara) name="Amara Diallo" email=amara@example.com ;;
	esac
	put "$1" 1 "$INIT" billing/__init__.py
	put "$1" 1 "$TYPES" billing/types.py
	put "$1" 1 "$API" billing/api.py
	put "$1" 1 "$PLANS" billing/plans.py
	put "$1" 1 "$STORE" billing/store.py
	put "$1" 1 "$SERVER" billing/server.py
	put "$1" 1 "$TESTS" tests/test_api.py
	put "$1" 1 "$README" README.md
	put "$1" 1 "$PYPROJECT" pyproject.toml
	git add -A
	GIT_AUTHOR_NAME=$name GIT_AUTHOR_EMAIL=$email GIT_COMMITTER_NAME=$name GIT_COMMITTER_EMAIL=$email \
		GIT_AUTHOR_DATE="$ts +0000" GIT_COMMITTER_DATE="$ts +0000" git commit -qm "$4"
}

IFS= read -r -d '' INIT <<'PY' || true
"""Customers, plans and subscriptions."""
PY

IFS= read -r -d '' TYPES <<'PY' || true
"""Shapes of the JSON bodies the API accepts."""

from typing import TypedDict  #@1-5
from typing import NotRequired, TypedDict  #@5


class PlanRef(TypedDict):
    id: str


class SubscriptionUpdate(TypedDict):
    plan: PlanRef
    seats: int  #@3
    interval: NotRequired[str]  #@5
    coupon: NotRequired[str]  #@8
    extend_trial_days: NotRequired[int]  #@14
PY

IFS= read -r -d '' API <<'PY' || true
"""HTTP handlers for customers and subscriptions: each takes the request body and returns (status, body)."""

import json
import logging  #@16
from datetime import date  #@10-14
from datetime import date, timedelta  #@14
from typing import cast

from billing import plans, store
from billing.types import SubscriptionUpdate

log = logging.getLogger(__name__)  #@16


class BadRequest(Exception):
    """The body is missing a field or has one of the wrong kind; answer 400."""


def _object(body):
    try:
        data = json.loads(body)
    except json.JSONDecodeError:
        raise BadRequest("the body isn't JSON") from None
    if not isinstance(data, dict):
        raise BadRequest("the body must be a JSON object")
    return data


def _require_str(data, key, max_len=200):
    value = data.get(key)
    if not isinstance(value, str) or not value.strip() or len(value) > max_len:
        raise BadRequest(f"{key} must be a non-empty string of at most {max_len} characters")
    return value.strip()


def create_customer(body):
    """POST /customers"""
    data = _object(body)
    name = _require_str(data, "name")
    email = _require_str(data, "email", 320)
    if "@" not in email:
        raise BadRequest("email must be an email address")
    return 201, store.add_customer(name=name, email=email)  #@1-4
    country = _require_str(data, "country", 2).upper()  #@4
    return 201, store.add_customer(name=name, email=email, country=country)  #@4
  #@2
  #@2
def list_invoices(customer_id):  #@2
    """GET /customers/<id>/invoices"""  #@2
    if store.customer(customer_id) is None:  #@2
        return 404, {"error": "no such customer"}  #@2
    return 200, {"invoices": store.invoices(customer_id)}  #@2


def update_subscription(customer_id, body):  #@1-10
def update_subscription(customer_id, body, today=None):  #@10
    """PUT /customers/<id>/subscription: change the plan, seats, billing interval, coupon or trial."""  #@14
    """PUT /customers/<id>/subscription: change the plan, seats, billing interval or coupon."""  #@8-14
    """PUT /customers/<id>/subscription: change the plan, seats or billing interval."""  #@5-8
    """PUT /customers/<id>/subscription: change the plan or seats."""  #@3-5
    """PUT /customers/<id>/subscription: change the plan."""  #@1-3
    payload = cast(SubscriptionUpdate, json.loads(body))
    sub = store.subscription(customer_id)
    if sub is None:
        return 404, {"error": "no subscription"}
    plan = plans.get(payload["plan"]["id"])
    if plan is None:
        return 400, {"error": "unknown plan"}
    seats = payload["seats"]  #@3
    if seats < plan.min_seats:  #@6
        return 400, {"error": f"{plan.name} needs at least {plan.min_seats} seats"}  #@6
    interval = payload.get("interval", "month")  #@5
    coupon = payload.get("coupon")  #@8
    if coupon and coupon not in plans.COUPONS:  #@8-15
        return 400, {"error": "unknown coupon"}  #@8-15
    if coupon and not plans.coupon_valid(coupon, today or date.today()):  #@15
        return 400, {"error": "unknown or expired coupon"}  #@15
    change = {"plan": plan.id}  #@1-3
    change = {"plan": plan.id, "seats": seats}  #@3-5
    change = {"plan": plan.id, "seats": seats, "interval": interval}  #@5-8
    change = {"plan": plan.id, "seats": seats, "interval": interval, "coupon": coupon}  #@8
    if sub["interval"] == "year" and seats < sub["seats"]:  #@12
        change["seats_at_renewal"] = seats  #@12
        change["seats"] = sub["seats"]  #@12
    if payload.get("extend_trial_days"):  #@14
        change["trial_ends"] = sub["trial_ends"] + timedelta(days=payload["extend_trial_days"])  #@14
    if plan.id != sub["plan"]:  #@10
        change["proration"] = str(plans.prorate(sub, plan, change["seats"], today or date.today()))  #@10
    store.update_subscription(customer_id, change)
    log.info("subscription %s changed: %s", customer_id, ", ".join(sorted(change)))  #@16
    return 200, store.subscription(customer_id)
  #@7
  #@7
def cancel_subscription(customer_id, body):  #@7
    """POST /customers/<id>/subscription/cancel"""  #@7
    data = _object(body)  #@7
    at_period_end = data.get("at_period_end", True)  #@7
    if not isinstance(at_period_end, bool):  #@7
        raise BadRequest("at_period_end must be true or false")  #@7
    if store.subscription(customer_id) is None:  #@7
        return 404, {"error": "no subscription"}  #@7
    store.cancel(customer_id, at_period_end)  #@7
    return 200, store.subscription(customer_id)  #@7
PY

IFS= read -r -d '' PLANS <<'PY' || true
"""Our plans, coupons, and what a billing period costs."""

from dataclasses import dataclass
from datetime import date  #@15
from decimal import Decimal


@dataclass(frozen=True)
class Plan:
    id: str
    name: str
    monthly_per_seat: Decimal
    min_seats: int = 1  #@6


PLANS = {
    p.id: p
    for p in (
        Plan("starter", "Starter", Decimal("8")),
        Plan("team", "Team", Decimal("12")),  #@1-6
        Plan("business", "Business", Decimal("20")),  #@1-6
        Plan("team", "Team", Decimal("12"), min_seats=3),  #@6
        Plan("business", "Business", Decimal("20"), min_seats=10),  #@6
        Plan("team_xl", "Team XL", Decimal("15"), min_seats=25),  #@17
    )
}
COUPONS = {"LAUNCH20": Decimal("0.20"), "NONPROFIT": Decimal("0.50")}  #@8-15
COUPONS = {"LAUNCH20": (Decimal("0.20"), date(2026, 12, 31)), "NONPROFIT": (Decimal("0.50"), date(2030, 1, 1))}  #@15


def get(plan_id):
    return PLANS.get(plan_id)
  #@10
  #@10
def total(plan, seats, interval):  #@10
    """What one billing period costs; a year is charged as ten months."""  #@10
    per_month = plan.monthly_per_seat * seats  #@10
    return per_month * 10 if interval == "year" else per_month  #@10
  #@10
  #@10
def prorate(sub, new_plan, seats, today):  #@10
    """The charge, or credit when negative, for switching plans partway through a period."""  #@10
    old = total(get(sub["plan"]), sub["seats"], sub["interval"])  #@10
    new = total(new_plan, seats, sub["interval"])  #@10
    length = 365 if sub["interval"] == "year" else 30  #@10
    return ((new - old) * (sub["period_end"] - today).days / length).quantize(Decimal("0.01"))  #@10
  #@15
  #@15
def coupon_valid(code, today):  #@15
    entry = COUPONS.get(code)  #@15
    return entry is not None and today <= entry[1]  #@15
PY

IFS= read -r -d '' STORE <<'PY' || true
"""In-memory storage, until the database is ready."""

import itertools
from datetime import date, timedelta

_customers = {}
_subscriptions = {}
_invoices = {}  #@2
_history = {}  #@11
_ids = itertools.count(1)


def add_customer(name, email):  #@1-4
def add_customer(name, email, country):  #@4
    customer_id = f"cus_{next(_ids)}"
    _customers[customer_id] = {"id": customer_id, "name": name, "email": email}  #@1-4
    _customers[customer_id] = {"id": customer_id, "name": name, "email": email, "country": country}  #@4
    _subscriptions[customer_id] = {
        "plan": "starter",
        "seats": 1,
        "interval": "month",
        "coupon": None,
        "trial_ends": date.today() + timedelta(days=14),
        "period_end": date.today() + timedelta(days=30),
        "cancel_at_period_end": False,  #@7
    }
    return _customers[customer_id]


def customer(customer_id):
    return _customers.get(customer_id)


def subscription(customer_id):
    return _subscriptions.get(customer_id)


def update_subscription(customer_id, change):
    _history.setdefault(customer_id, []).append(dict(_subscriptions[customer_id]))  #@11
    _subscriptions[customer_id].update(change)
  #@2
  #@2
def invoices(customer_id):  #@2
    return list(_invoices.get(customer_id, []))  #@2
  #@7
  #@7
def cancel(customer_id, at_period_end):  #@7
    if at_period_end:  #@7
        _subscriptions[customer_id]["cancel_at_period_end"] = True  #@7
    else:  #@7
        del _subscriptions[customer_id]  #@7
  #@11
  #@11
def history(customer_id):  #@11
    return list(_history.get(customer_id, []))  #@11
PY

IFS= read -r -d '' SERVER <<'PY' || true
"""Serve the API with the standard library's HTTP server."""

import json
import re
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from billing import api

ROUTES = [
    ("POST", re.compile(r"^/customers$"), lambda m, body: api.create_customer(body)),
    ("GET", re.compile(r"^/customers/([\w-]+)/invoices$"), lambda m, body: api.list_invoices(m[1])),  #@2
    ("PUT", re.compile(r"^/customers/([\w-]+)/subscription$"), lambda m, body: api.update_subscription(m[1], body)),
    ("POST", re.compile(r"^/customers/([\w-]+)/subscription/cancel$"), lambda m, body: api.cancel_subscription(m[1], body)),  #@7
]


class Handler(BaseHTTPRequestHandler):
    def _route(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        for method, pattern, handle in ROUTES:
            m = pattern.match(self.path)
            if m and method == self.command:
                try:
                    status, out = handle(m, body)
                except api.BadRequest as e:
                    status, out = 400, {"error": str(e)}
                break
        else:
            status, out = 404, {"error": "not found"}
        payload = json.dumps(out, default=str).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    do_GET = do_POST = do_PUT = _route


if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", 8070), Handler).serve_forever()
PY

IFS= read -r -d '' TESTS <<'PY' || true
import json
import unittest

from billing import api


def customer():
    status, body = api.create_customer(json.dumps({"name": "Ada", "email": "ada@example.com"}))  #@1-4
    status, body = api.create_customer(json.dumps({"name": "Ada", "email": "ada@example.com", "country": "se"}))  #@4
    return body["id"]


class CustomerTest(unittest.TestCase):
    def test_create(self):
        status, body = api.create_customer(json.dumps({"name": "Ada", "email": "ada@example.com"}))  #@1-4
        status, body = api.create_customer(json.dumps({"name": "Ada", "email": "ada@example.com", "country": "se"}))  #@4
        self.assertEqual((status, body["name"]), (201, "Ada"))

    def test_rejects_missing_email(self):
        with self.assertRaises(api.BadRequest):
            api.create_customer(json.dumps({"name": "Ada"}))


class SubscriptionTest(unittest.TestCase):
    def test_change_plan(self):
        cid = customer()
        status, body = api.update_subscription(cid, json.dumps({"plan": {"id": "business"}}))  #@1-3
        status, body = api.update_subscription(cid, json.dumps({"plan": {"id": "business"}, "seats": 12}))  #@3
        self.assertEqual((status, body["plan"]), (200, "business"))

    def test_unknown_plan(self):
        status, _ = api.update_subscription(customer(), json.dumps({"plan": {"id": "gold"}}))  #@1-3
        status, _ = api.update_subscription(customer(), json.dumps({"plan": {"id": "gold"}, "seats": 1}))  #@3
        self.assertEqual(status, 400)
  #@9
  #@9
class InvoiceTest(unittest.TestCase):  #@9
    def test_new_customer_has_none(self):  #@9
        self.assertEqual(api.list_invoices(customer()), (200, {"invoices": []}))  #@9
  #@9
    def test_unknown_customer(self):  #@9
        self.assertEqual(api.list_invoices("cus_nobody")[0], 404)  #@9


if __name__ == "__main__":
    unittest.main()
PY

IFS= read -r -d '' README <<'MD' || true
# billing

Customers, plans and subscriptions behind a small JSON API.
  #@13
    POST /customers                            {"name", "email", "country"}  #@13
    GET  /customers/<id>/invoices  #@13
    PUT  /customers/<id>/subscription          {"plan": {"id"}, "seats", "interval", "coupon", "extend_trial_days"}  #@13
    POST /customers/<id>/subscription/cancel   {"at_period_end"}  #@13

## Tests

    python3 -m unittest discover -s tests
MD

IFS= read -r -d '' PYPROJECT <<'TOML' || true
[project]
name = "billing"
version = "0.9.0"
requires-python = ">=3.11"
TOML

commit 1 320 elena "Customers and subscriptions API"
commit 2 305 elena "List a customer's invoices"
commit 3 290 jun "Seats on subscriptions"
commit 4 276 jun "Customer country for tax"
commit 5 262 amara "Yearly billing"
commit 6 247 amara "Minimum seats per plan"
commit 7 230 jun "Cancel now or at the end of the period"
commit 8 214 elena "Coupons"
commit 9 198 jun "Tests for invoices"
commit 10 180 amara "Prorate plan changes partway through a period"
commit 11 160 elena "Keep subscription history"
commit 12 139 amara "Fewer seats on a yearly plan take effect at renewal"
commit 13 117 jun "README: API overview"
commit 14 95 elena "Extend trials"
commit 15 70 amara "Reject expired coupons"
commit 16 44 jun "Log subscription changes"
commit 17 20 elena "Team XL plan"
