#!/bin/bash
# An event worker whose handlers register themselves with a decorator. The
# handlers package imports every submodule at import time so the decorators
# run, and the worker calls dispatch(). The change adds a refund handler.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p handlers

cat > pyproject.toml <<'TOML'
[project]
name = "event-worker"
version = "0.5.0"
requires-python = ">=3.9"
dependencies = []
TOML

cat > handlers/registry.py <<'PY'
"""A decorator registry that maps event types to handler functions."""

from __future__ import annotations

from typing import Callable, Dict

Handler = Callable[[dict], None]

_HANDLERS: Dict[str, Handler] = {}


class NoHandler(Exception):
    """Raised when an event arrives with no registered handler."""


def register(event_type: str) -> Callable[[Handler], Handler]:
    def decorator(func: Handler) -> Handler:
        _HANDLERS[event_type] = func
        return func

    return decorator


def dispatch(event: dict) -> None:
    event_type = event.get("type")
    handler = _HANDLERS.get(event_type)
    if handler is None:
        raise NoHandler(event_type)
    handler(event)
PY

cat > handlers/__init__.py <<'PY'
"""Importing this package registers every handler submodule.

Each submodule decorates its functions with @register(...), so they must be
imported for the registry to know about them. Importing them here means the
worker only has to import this package.
"""

from __future__ import annotations

import importlib
import pkgutil

for _module in pkgutil.iter_modules(__path__):
    if _module.name != "registry":
        importlib.import_module("{}.{}".format(__name__, _module.name))
PY

cat > handlers/invoices.py <<'PY'
"""Invoice event handlers."""

from __future__ import annotations

from handlers.registry import register


@register("invoice.paid")
def on_invoice_paid(event: dict) -> None:
    invoice_id = event["invoice_id"]
    print("invoice {} marked paid".format(invoice_id))
PY

cat > worker.py <<'PY'
"""Reads events off the stream and dispatches each to its handler."""

from __future__ import annotations

import handlers  # noqa: F401  (importing registers every handler)
from handlers.registry import dispatch


def run(events) -> None:
    for event in events:
        dispatch(event)
PY

cat > README.md <<'MD'
# event-worker

Handlers register themselves with `@register("<event.type>")`. The `handlers`
package imports each submodule at import time, and `worker.run` dispatches each
incoming event to the handler registered for its type.
MD

git add -A
git commit -qm "Add the handler registry, invoice handler and worker"

cat > handlers/refunds.py <<'PY'
"""Refund event handlers."""

from __future__ import annotations

from handlers.registry import register


@register("refund.issued")
def on_refund_issued(event: dict) -> None:
    refund_id = event["refund_id"]
    order_id = event["order_id"]
    print("refund {} issued for order {}".format(refund_id, order_id))
PY
