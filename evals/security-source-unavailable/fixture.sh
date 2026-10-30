#!/bin/bash
# A small Python web app with server-side sessions, committed, plus an
# uncommitted change to the attributes of its session cookie.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p app
cat > app/__init__.py <<'PY'
PY
cat > app/session.py <<'PY'
"""Server-side sessions. The browser holds only a random session ID in a cookie."""

import secrets
import time

SESSION_COOKIE = "session"
SESSION_TTL_SECONDS = 8 * 60 * 60

_sessions: dict[str, tuple[str, float]] = {}


def create_session(user_id: str) -> str:
    """Starts a session after sign-in, with a new ID every time."""
    session_id = secrets.token_urlsafe(32)
    _sessions[session_id] = (user_id, time.time() + SESSION_TTL_SECONDS)
    return session_id


def user_for(session_id: str | None) -> str | None:
    entry = _sessions.get(session_id) if session_id else None
    if entry is None:
        return None
    user_id, expires_at = entry
    if time.time() >= expires_at:
        del _sessions[session_id]
        return None
    return user_id


def end_session(session_id: str | None) -> None:
    if session_id:
        _sessions.pop(session_id, None)


def session_cookie(session_id: str) -> str:
    """The Set-Cookie value that starts a session."""
    return f"{SESSION_COOKIE}={session_id}; Path=/"


def cleared_session_cookie() -> str:
    """The Set-Cookie value that ends a session."""
    return f"{SESSION_COOKIE}=; Path=/; Max-Age=0"
PY
cat > app/web.py <<'PY'
"""Ties the session store to request cookies. Sign-in itself happens elsewhere."""

from http.cookies import CookieError, SimpleCookie

from . import session


def _session_id(cookie_header: str | None) -> str | None:
    if not cookie_header:
        return None
    cookies = SimpleCookie()
    try:
        cookies.load(cookie_header)
    except CookieError:
        return None
    morsel = cookies.get(session.SESSION_COOKIE)
    return morsel.value if morsel else None


def current_user(cookie_header: str | None) -> str | None:
    return session.user_for(_session_id(cookie_header))


def sign_in(user_id: str) -> list[tuple[str, str]]:
    """Response headers to send once the sign-in flow has verified the user."""
    return [("Set-Cookie", session.session_cookie(session.create_session(user_id)))]


def sign_out(cookie_header: str | None) -> list[tuple[str, str]]:
    session.end_session(_session_id(cookie_header))
    return [("Set-Cookie", session.cleared_session_cookie())]
PY
git add -A
git commit -qm "Add server-side sessions"
cat > app/session.py <<'PY'
"""Server-side sessions. The browser holds only a random session ID in a cookie."""

import secrets
import time

# __Host- makes browsers require Secure and Path=/ and refuse a Domain attribute.
SESSION_COOKIE = "__Host-session"
SESSION_TTL_SECONDS = 8 * 60 * 60

_sessions: dict[str, tuple[str, float]] = {}


def create_session(user_id: str) -> str:
    """Starts a session after sign-in, with a new ID every time."""
    session_id = secrets.token_urlsafe(32)
    _sessions[session_id] = (user_id, time.time() + SESSION_TTL_SECONDS)
    return session_id


def user_for(session_id: str | None) -> str | None:
    entry = _sessions.get(session_id) if session_id else None
    if entry is None:
        return None
    user_id, expires_at = entry
    if time.time() >= expires_at:
        del _sessions[session_id]
        return None
    return user_id


def end_session(session_id: str | None) -> None:
    if session_id:
        _sessions.pop(session_id, None)


def _cookie(value: str, max_age: int | None = None) -> str:
    """The session cookie with the attributes it always carries."""
    attributes = [f"{SESSION_COOKIE}={value}", "Path=/", "Secure", "HttpOnly", "SameSite=Lax"]
    if max_age is not None:
        attributes.append(f"Max-Age={max_age}")
    return "; ".join(attributes)


def session_cookie(session_id: str) -> str:
    """The Set-Cookie value that starts a session."""
    return _cookie(session_id)


def cleared_session_cookie() -> str:
    """The Set-Cookie value that ends a session."""
    return _cookie("", max_age=0)
PY
