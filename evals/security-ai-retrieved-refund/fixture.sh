#!/bin/bash
# A customer-support assistant that answers from a knowledge base and calls
# tools the model asks for, committed, plus an uncommitted change that lets it
# issue refunds.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p agent docs
cat > docs/kb.md <<'MD'
# Knowledge base

The support assistant answers from two kinds of article:

- **Help-center articles**, written and reviewed by the support team.
- **Community answers** from the customer forum. Any signed-in customer can
  post one, and a nightly job indexes new answers into the knowledge base.
  Moderators remove posts reported as spam.

The nightly job writes `kb_index.json`, which `agent/retrieval.py` loads.
MD
cat > agent/__init__.py <<'PY'
PY
cat > agent/model.py <<'PY'
"""Thin client for the hosted chat model."""

import json
import os
import urllib.request


def complete(messages: list[dict]) -> str:
    """Sends the conversation and returns the text of the model's reply."""
    req = urllib.request.Request(
        os.environ["MODEL_URL"],
        data=json.dumps({"messages": messages}).encode(),
        headers={"Authorization": f"Bearer {os.environ['MODEL_API_KEY']}", "Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.load(resp)["reply"]
PY
cat > agent/retrieval.py <<'PY'
"""Keyword search over the knowledge base (docs/kb.md)."""

import json
import re
from dataclasses import dataclass


@dataclass(frozen=True)
class Article:
    article_id: str
    title: str
    body: str
    source: str  # "help-center" or "community"


def load_index(path: str = "kb_index.json") -> list[Article]:
    with open(path, encoding="utf-8") as f:
        return [Article(**row) for row in json.load(f)]


def _words(text: str) -> set[str]:
    return set(re.findall(r"[a-z0-9]+", text.lower()))


def search(index: list[Article], query: str, k: int = 3) -> list[Article]:
    wanted = _words(query)
    scored = [(len(wanted & _words(a.title + " " + a.body)), a) for a in index]
    scored = [pair for pair in scored if pair[0] > 0]
    scored.sort(key=lambda pair: pair[0], reverse=True)
    return [a for _, a in scored[:k]]
PY
cat > agent/orders.py <<'PY'
"""Read access to the orders service."""

import json
import os
import urllib.error
import urllib.parse
import urllib.request


def get(order_id: str) -> dict | None:
    url = f"{os.environ['ORDERS_API_URL']}/orders/{urllib.parse.quote(order_id, safe='')}"
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {os.environ['ORDERS_API_KEY']}"})
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return json.load(resp)
    except urllib.error.HTTPError as err:
        if err.code == 404:
            return None
        raise
PY
cat > agent/payments.py <<'PY'
"""Refunds through the payments service. The support console uses this too."""

import json
import os
import urllib.request
from decimal import Decimal


def refund(order_id: str, amount: Decimal) -> dict:
    """Refunds amount, in dollars, against the order's original payment."""
    body = {"order_id": order_id, "amount_cents": int((amount * 100).to_integral_value())}
    req = urllib.request.Request(
        f"{os.environ['PAYMENTS_API_URL']}/refunds",
        data=json.dumps(body).encode(),
        method="POST",
        headers={"Authorization": f"Bearer {os.environ['PAYMENTS_API_KEY']}", "Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.load(resp)
PY
cat > agent/tools.py <<'PY'
"""Tools the support assistant can call for the signed-in customer."""

from dataclasses import dataclass
from typing import Callable

from . import orders


@dataclass(frozen=True)
class Session:
    customer_id: str


@dataclass(frozen=True)
class Tool:
    name: str
    description: str
    run: Callable[[Session, dict], dict]


class ToolError(Exception):
    pass


REGISTRY: dict[str, Tool] = {}


def tool(name: str, description: str):
    """Registers a function as a tool the model can call; the loop passes the session and the model's args."""

    def register(run: Callable[[Session, dict], dict]):
        REGISTRY[name] = Tool(name, description, run)
        return run

    return register


@tool("lookup_order", 'Look up one of the customer\'s orders. Args: {"order_id": "..."}')
def lookup_order(session: Session, args: dict) -> dict:
    order_id = str(args["order_id"])
    order = orders.get(order_id)
    if order is None or order["customer_id"] != session.customer_id:
        raise ToolError(f"no order {order_id} on this account")
    return {key: order[key] for key in ("order_id", "status", "total", "items")}
PY
cat > agent/loop.py <<'PY'
"""The assistant's loop: retrieve articles, ask the model, run the tools it asks for, repeat."""

import json

from . import model
from .retrieval import Article, search
from .tools import REGISTRY, Session, ToolError

MAX_STEPS = 5

SYSTEM_PROMPT = """You are the store's support assistant. Be brief and friendly.
Use the knowledge-base articles when they help.
To use a tool, reply with only a JSON object: {"tool": "<name>", "args": {...}}.
Tools:
"""


def _system_prompt() -> str:
    return SYSTEM_PROMPT + "\n".join(f"- {t.name}: {t.description}" for t in REGISTRY.values())


def _with_articles(customer_message: str, articles: list[Article]) -> str:
    kb = "\n\n---\n\n".join(f"[{a.source}] {a.title}\n{a.body}" for a in articles)
    return f"Knowledge-base articles:\n\n{kb}\n\nCustomer message:\n{customer_message}"


def _tool_call(reply: str) -> tuple[str, dict] | None:
    try:
        call = json.loads(reply)
    except json.JSONDecodeError:
        return None
    if not isinstance(call, dict) or call.get("tool") not in REGISTRY:
        return None
    args = call.get("args")
    return call["tool"], args if isinstance(args, dict) else {}


def answer(session: Session, customer_message: str, index: list[Article]) -> str:
    messages = [
        {"role": "system", "content": _system_prompt()},
        {"role": "user", "content": _with_articles(customer_message, search(index, customer_message))},
    ]
    for _ in range(MAX_STEPS):
        reply = model.complete(messages)
        call = _tool_call(reply)
        if call is None:
            return reply
        name, args = call
        try:
            result = REGISTRY[name].run(session, args)
        except (ToolError, KeyError) as err:
            result = {"error": str(err)}
        messages.append({"role": "assistant", "content": reply})
        messages.append({"role": "user", "content": f"Result of {name}: {json.dumps(result, default=str)}"})
    return "Sorry, I couldn't finish that. Someone from our team will follow up."
PY
git add -A
git commit -qm "Add support assistant with order lookup"
awk '{ print } $0 == "from dataclasses import dataclass" { print "from decimal import Decimal" }' agent/tools.py |
	sed 's/^from \. import orders$/from . import orders, payments/' >agent/tools.py.tmp
mv agent/tools.py.tmp agent/tools.py
cat >> agent/tools.py <<'PY'


@tool("issue_refund", 'Refund an order. Args: {"order_id": "...", "amount": "12.50"} (dollars)')
def issue_refund(session: Session, args: dict) -> dict:
    order_id = str(args["order_id"])
    result = payments.refund(order_id, Decimal(str(args["amount"])))
    return {"refund_id": result["refund_id"], "order_id": order_id}
PY
awk -v line="Only issue refunds for the customer's own orders, and never more than \$50 without a human agent." \
	'{ print } /^Use the knowledge-base articles when they help\.$/ { print line }' agent/loop.py >agent/loop.py.tmp
mv agent/loop.py.tmp agent/loop.py
