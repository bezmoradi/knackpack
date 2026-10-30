#!/bin/bash
# A small request-handling package (users, permissions, response builders),
# committed, plus an uncommitted change that moves the per-request values the
# handlers need into one shared helper.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p app
touch app/__init__.py
cat > pyproject.toml <<'TOML'
[project]
name = "account-api"
version = "0.4.0"
requires-python = ">=3.11"
dependencies = []
TOML
cat > app/users.py <<'PY'
"""Users as the session middleware hands them to the handlers."""

from dataclasses import dataclass


@dataclass(frozen=True)
class User:
    user_id: str
    org_name: str
    role: str
PY
cat > app/permissions.py <<'PY'
"""What each role may do."""

from app.users import User

EXPORT_ROLES = frozenset({"admin", "analyst"})


def can_export(user: User) -> bool:
    """Exports contain every record in the organisation, so only some roles get them."""
    return user.role in EXPORT_ROLES
PY
cat > app/handlers.py <<'PY'
"""Response builders for the account API."""

from app.permissions import can_export
from app.users import User


def profile_response(user: User) -> dict:
    return {
        "status": 200,
        "body": {
            "user_id": user.user_id,
            "org_name": user.org_name,
            "can_export": can_export(user),
        },
    }


def export_response(user: User, rows: list[dict]) -> dict:
    if not can_export(user):
        return {"status": 403, "body": {"error": "export not allowed"}}
    return {"status": 200, "body": {"org_name": user.org_name, "rows": rows}}
PY
git add -A
git commit -qm "Add profile and export responses"
cat > app/context.py <<'PY'
"""The values every handler needs about the caller, built in one place."""

from app.permissions import can_export
from app.users import User


def request_context(user: User, overrides: dict = {}) -> dict:
    """Return the caller's user_id, org_name and can_export.

    Callers that already know some of these values, such as the support view
    acting inside a customer's organisation, pass them in overrides and they
    win over the ones derived from the user. user_id always comes from the
    user, so the audit trail names whoever is really making the request.
    """
    overrides["user_id"] = user.user_id
    overrides.setdefault("org_name", user.org_name)
    overrides.setdefault("can_export", can_export(user))
    return overrides
PY
cat > app/handlers.py <<'PY'
"""Response builders for the account API."""

from app.context import request_context
from app.users import User


def profile_response(user: User) -> dict:
    ctx = request_context(user)
    return {
        "status": 200,
        "body": {
            "user_id": ctx["user_id"],
            "org_name": ctx["org_name"],
            "can_export": ctx["can_export"],
        },
    }


def export_response(user: User, rows: list[dict]) -> dict:
    ctx = request_context(user)
    if not ctx["can_export"]:
        return {"status": 403, "body": {"error": "export not allowed"}}
    return {"status": 200, "body": {"org_name": ctx["org_name"], "rows": rows}}


def support_profile_response(agent: User, customer_org: str) -> dict:
    """What a support agent sees while working inside a customer's organisation."""
    if agent.role != "support":
        return {"status": 403, "body": {"error": "support only"}}
    ctx = request_context(agent, {"org_name": customer_org, "can_export": False})
    return {
        "status": 200,
        "body": {
            "user_id": ctx["user_id"],
            "org_name": ctx["org_name"],
            "can_export": ctx["can_export"],
        },
    }
PY
