#!/bin/bash
# A notification service with a year of history. notify/errors.py, a list of
# one-line error code constants with focused tests in tests/test_errors.py,
# changes in 20 of the 25 commits because every feature adds a code; it has no
# branches and no long function. notify/api.py is the larger file that also
# changes often.
# Each commit writes every file at its step: a line ending in "#@N" exists from
# step N on, and one ending in "#@N-M" from step N until step M.
set -euo pipefail
git init -q -b main
git config user.name "Alex Kim"
git config user.email "alex@example.com"
now=$(date +%s)
mkdir -p notify/templates/en notify/templates/de tests

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
	alex) name="Alex Kim" email=alex@example.com ;;
	dana) name="Dana Okafor" email=dana@example.com ;;
	kofi) name="Kofi Mensah" email=kofi@example.com ;;
	esac
	put "$1" 1 "$ERRORS" notify/errors.py
	put "$1" 1 "$API" notify/api.py
	put "$1" 1 "$MAIL" notify/mail.py
	put "$1" 4 "$SMS" notify/sms.py
	put "$1" 1 "$TEMPLATES" notify/templates.py
	put "$1" 1 "$STORE" notify/store.py
	put "$1" 1 "$SERVER" notify/server.py
	put "$1" 1 "$ERRORTESTS" tests/test_errors.py
	put "$1" 5 "$TEMPLATETESTS" tests/test_templates.py
	put "$1" 1 "$README" README.md
	git add -A
	GIT_AUTHOR_NAME=$name GIT_AUTHOR_EMAIL=$email GIT_COMMITTER_NAME=$name GIT_COMMITTER_EMAIL=$email \
		GIT_AUTHOR_DATE="$ts +0000" GIT_COMMITTER_DATE="$ts +0000" git commit -qm "$4"
}

IFS= read -r -d '' ERRORS <<'PY' || true
"""The error codes the API returns, each with its HTTP status and message."""

from dataclasses import dataclass


@dataclass(frozen=True)
class ErrorCode:
    code: str
    status: int
    message: str


INVALID_JSON = ErrorCode("invalid_json", 400, "The request body isn't a JSON object.")
UNKNOWN_TEMPLATE = ErrorCode("unknown_template", 404, "There's no template with that name.")
RECIPIENT_MISSING = ErrorCode("recipient_missing", 400, "Give at least one recipient.")  #@2
INVALID_EMAIL = ErrorCode("invalid_email", 400, "That isn't an email address.")  #@3
INVALID_PHONE = ErrorCode("invalid_phone", 400, "Phone numbers need the international format, such as +4915112345678.")  #@4
TEMPLATE_VARIABLE_MISSING = ErrorCode("template_variable_missing", 400, "The template needs a variable you didn't give.")  #@5
RATE_LIMITED = ErrorCode("rate_limited", 429, "This recipient has had too many messages in the last hour.")  #@6
UNSUBSCRIBED = ErrorCode("unsubscribed", 409, "This recipient has unsubscribed.")  #@7
QUIET_HOURS = ErrorCode("quiet_hours", 409, "We don't send texts at night.")  #@8-24
QUIET_HOURS = ErrorCode("quiet_hours", 409, "We don't send texts between 21:00 and 08:00; schedule it for the morning.")  #@24
DUPLICATE_REQUEST = ErrorCode("duplicate_request", 409, "A request with this idempotency key was already sent.")  #@9
MESSAGE_TOO_LONG = ErrorCode("message_too_long", 400, "Texts can be at most 1600 characters.")  #@10
UNKNOWN_CHANNEL = ErrorCode("unknown_channel", 400, "The channel must be email or sms.")  #@12
NOT_FOUND = ErrorCode("not_found", 404, "There's nothing at that address.")  #@13
PROVIDER_UNAVAILABLE = ErrorCode("provider_unavailable", 503, "The provider didn't answer; try again shortly.")  #@14
ATTACHMENT_TOO_LARGE = ErrorCode("attachment_too_large", 413, "Attachments can add up to at most 10 MB.")  #@16
SCHEDULE_IN_PAST = ErrorCode("schedule_in_past", 400, "The send time has already passed.")  #@17
LOCALE_UNSUPPORTED = ErrorCode("locale_unsupported", 400, "We have no templates in that language.")  #@18
BATCH_TOO_LARGE = ErrorCode("batch_too_large", 413, "Send to at most 100 recipients at a time.")  #@20
SENDER_NOT_VERIFIED = ErrorCode("sender_not_verified", 403, "That sender address isn't verified.")  #@21
TEMPLATE_DISABLED = ErrorCode("template_disabled", 409, "That template is switched off.")  #@22


class ApiError(Exception):
    """Raised anywhere in a request to answer with an error code."""

    def __init__(self, error, detail=None):
        super().__init__(error.message)
        self.error = error
        self.detail = detail


def response(error, detail=None):
    """The status and JSON body for an error."""
    body = {"error": error.code, "message": error.message}
    if detail:
        body["detail"] = detail
    return error.status, body
PY

IFS= read -r -d '' API <<'PY' || true
"""HTTP API: POST /messages sends a templated message by email or SMS."""

import json
import uuid
from datetime import datetime, timezone

from notify import errors, mail, store, templates  #@1-4
from notify import errors, mail, sms, store, templates  #@4

CHANNELS = ("email", "sms")  #@12
MAX_BATCH = 100  #@20


def _body(raw):
    try:
        body = json.loads(raw)
    except json.JSONDecodeError:
        raise errors.ApiError(errors.INVALID_JSON) from None
    if not isinstance(body, dict):
        raise errors.ApiError(errors.INVALID_JSON)
    return body


def send(raw, now=None):
    """Handle POST /messages and return (status, body)."""
    body = _body(raw)
    now = now or datetime.now(timezone.utc)
    channel = body.get("channel", "email")
    if channel not in CHANNELS:  #@12
        raise errors.ApiError(errors.UNKNOWN_CHANNEL, str(channel))  #@12
    recipients = body.get("to") or []
    if isinstance(recipients, str):
        recipients = [recipients]
    if not recipients:  #@2
        raise errors.ApiError(errors.RECIPIENT_MISSING)  #@2
    if len(recipients) > MAX_BATCH:  #@20
        raise errors.ApiError(errors.BATCH_TOO_LARGE, f"{len(recipients)} recipients")  #@20
    key = body.get("idempotency_key")  #@9
    if key and store.seen(key):  #@9
        raise errors.ApiError(errors.DUPLICATE_REQUEST, key)  #@9
    send_at = None  #@17
    if "send_at" in body:  #@17
        send_at = datetime.fromisoformat(body["send_at"])  #@17
        if send_at.astimezone(timezone.utc) <= now:  #@17
            raise errors.ApiError(errors.SCHEDULE_IN_PAST)  #@17
    subject, text = templates.render(body.get("template"), body.get("variables", {}))  #@1-18
    subject, text = templates.render(body.get("template"), body.get("variables", {}), body.get("locale", "en"))  #@18
    ids = []
    for to in recipients:
        if store.unsubscribed(to):  #@7
            raise errors.ApiError(errors.UNSUBSCRIBED, to)  #@7
        if not store.allow(to):  #@6
            raise errors.ApiError(errors.RATE_LIMITED, to)  #@6
        message_id = str(uuid.uuid4())
        mail.send(to, subject, text)  #@1-4
        if channel == "sms":  #@4-17
            sms.send(to, text)  #@4-17
        else:  #@4-17
            mail.send(to, subject, text)  #@4-17
        if send_at:  #@17
            store.schedule(message_id, channel, to, subject, text, send_at)  #@17
        elif channel == "sms":  #@17
            sms.send(to, text)  #@17
        else:  #@17
            mail.send(to, subject, text)  #@17
        store.record(message_id, channel, to)  #@13
        ids.append(message_id)
    if key:  #@9
        store.remember(key)  #@9
    return 202, {"ids": ids}
  #@13
  #@13
def get_message(message_id):  #@13
    """Handle GET /messages/<id>."""  #@13
    message = store.get(message_id)  #@13
    if message is None:  #@13
        raise errors.ApiError(errors.NOT_FOUND, message_id)  #@13
    return 200, message  #@13
  #@25
  #@25
def preview(raw):  #@25
    """Handle POST /previews: render a template without sending it."""  #@25
    body = _body(raw)  #@25
    subject, text = templates.render(body.get("template"), body.get("variables", {}), body.get("locale", "en"))  #@25
    return 200, {"subject": subject, "text": text}  #@25


def handle(method, path, raw):
    """Route a request, turning an ApiError into its error response."""
    try:
        if method == "POST" and path == "/messages":
            return send(raw)
        if method == "POST" and path == "/previews":  #@25
            return preview(raw)  #@25
        if method == "GET" and path.startswith("/messages/"):  #@13
            return get_message(path.removeprefix("/messages/"))  #@13
        return 404, {"error": "not_found"}  #@1-13
        raise errors.ApiError(errors.NOT_FOUND, path)  #@13
    except errors.ApiError as e:
        return errors.response(e.error, e.detail)
PY

IFS= read -r -d '' MAIL <<'PY' || true
"""Email through the SMTP relay."""

import re  #@3
import smtplib
from email.message import EmailMessage

from notify import errors

RELAY = ("localhost", 25)
DEFAULT_SENDER = "notifications@example.com"
VERIFIED_SENDERS = {"notifications@example.com", "billing@example.com"}  #@21
MAX_ATTACHMENT_BYTES = 10 * 1024 * 1024  #@16
ADDRESS = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")  #@3


def build(to, subject, text, sender=DEFAULT_SENDER, attachments=()):
    """Return the message to send, or raise ApiError when it can't be sent."""
    if not ADDRESS.match(to):  #@3
        raise errors.ApiError(errors.INVALID_EMAIL, to)  #@3
    if sender not in VERIFIED_SENDERS:  #@21
        raise errors.ApiError(errors.SENDER_NOT_VERIFIED, sender)  #@21
    msg = EmailMessage()
    msg["From"] = sender
    msg["To"] = to
    msg["Subject"] = subject
    msg.set_content(text)
    total = 0  #@16
    for name, data, mime in attachments:
        total += len(data)  #@16
        if total > MAX_ATTACHMENT_BYTES:  #@16
            raise errors.ApiError(errors.ATTACHMENT_TOO_LARGE, name)  #@16
        maintype, _, subtype = mime.partition("/")
        msg.add_attachment(data, maintype=maintype, subtype=subtype, filename=name)
    return msg


def send(to, subject, text, sender=DEFAULT_SENDER, attachments=()):
    """Send one email through the relay."""
    msg = build(to, subject, text, sender, attachments)
    with smtplib.SMTP(*RELAY, timeout=10) as smtp:  #@1-14
        smtp.send_message(msg)  #@1-14
    try:  #@14
        with smtplib.SMTP(*RELAY, timeout=10) as smtp:  #@14
            smtp.send_message(msg)  #@14
    except OSError:  #@14
        raise errors.ApiError(errors.PROVIDER_UNAVAILABLE, "email relay") from None  #@14
PY

IFS= read -r -d '' SMS <<'PY' || true
"""SMS through the gateway's HTTP API."""

import json
import re
import urllib.request
from datetime import datetime, time  #@8

from notify import errors

GATEWAY = "https://sms-gateway.internal/v1/messages"
TIMEOUT = 5  #@4-23
TIMEOUT = 15  #@23
PHONE = re.compile(r"^\+[1-9][0-9]{6,14}$")
MAX_LENGTH = 1600  #@10
QUIET_START, QUIET_END = time(21, 0), time(8, 0)  #@8
  #@8
  #@8
def in_quiet_hours(at):  #@8
    """Whether a local time falls between 21:00 and 08:00."""  #@8
    t = at.time()  #@8
    return t >= QUIET_START or t < QUIET_END  #@8


def send(to, text, now=None):
    """Send one text, or raise ApiError when it can't be sent. Returns the gateway's message ID."""
    if not PHONE.match(to):
        raise errors.ApiError(errors.INVALID_PHONE, to)
    if len(text) > MAX_LENGTH:  #@10
        raise errors.ApiError(errors.MESSAGE_TOO_LONG, f"{len(text)} characters")  #@10
    if in_quiet_hours(now or datetime.now()):  #@8
        raise errors.ApiError(errors.QUIET_HOURS)  #@8
    request = urllib.request.Request(
        GATEWAY,
        data=json.dumps({"to": to, "text": text}).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=TIMEOUT) as response:  #@4-14
        return json.load(response)["id"]  #@4-14
    try:  #@14
        with urllib.request.urlopen(request, timeout=TIMEOUT) as response:  #@14
            return json.load(response)["id"]  #@14
    except OSError:  #@14
        raise errors.ApiError(errors.PROVIDER_UNAVAILABLE, "SMS gateway") from None  #@14
PY

IFS= read -r -d '' TEMPLATES <<'PY' || true
"""Message templates: a subject line, a blank line, then the body, with {variable} placeholders."""

import string  #@5
from pathlib import Path

from notify import errors  #@1-22
from notify import errors, store  #@22

TEMPLATE_DIR = Path(__file__).parent / "templates"
LOCALES = ("en", "de")  #@18


def load(name):  #@1-18
def load(name, locale="en"):  #@18
    """Return the template's text, or raise ApiError when there's no such template."""
    if not isinstance(name, str) or not name.isidentifier():
        raise errors.ApiError(errors.UNKNOWN_TEMPLATE, str(name))
    if locale not in LOCALES:  #@18
        raise errors.ApiError(errors.LOCALE_UNSUPPORTED, str(locale))  #@18
    path = TEMPLATE_DIR / "en" / f"{name}.txt"  #@1-18
    path = TEMPLATE_DIR / locale / f"{name}.txt"  #@18
    if not path.is_file():
        raise errors.ApiError(errors.UNKNOWN_TEMPLATE, name)
    return path.read_text(encoding="utf-8")


def render(name, variables):  #@1-18
def render(name, variables, locale="en"):  #@18
    """Return (subject, body) with the variables filled in."""
    if store.template_disabled(name):  #@22
        raise errors.ApiError(errors.TEMPLATE_DISABLED, name)  #@22
    text = load(name)  #@1-18
    text = load(name, locale)  #@18
    missing = {f for _, f, _, _ in string.Formatter().parse(text) if f and f not in variables}  #@5
    if missing:  #@5
        raise errors.ApiError(errors.TEMPLATE_VARIABLE_MISSING, ", ".join(sorted(missing)))  #@5
    subject, _, body = text.format_map(variables).partition("\n")
    return subject, body.lstrip("\n")
PY

IFS= read -r -d '' STORE <<'PY' || true
"""Message state in SQLite: sends, rate limits, unsubscribes and idempotency keys."""

import sqlite3
import time

DB_PATH = "notify.db"
RATE_LIMIT = 5  #@6
RATE_WINDOW_SECONDS = 3600  #@6

SCHEMA = """
CREATE TABLE IF NOT EXISTS sends (recipient TEXT NOT NULL, at REAL NOT NULL);
CREATE TABLE IF NOT EXISTS unsubscribes (recipient TEXT PRIMARY KEY);  #@7
CREATE TABLE IF NOT EXISTS idempotency_keys (key TEXT PRIMARY KEY, at REAL NOT NULL);  #@9
CREATE TABLE IF NOT EXISTS messages (id TEXT PRIMARY KEY, channel TEXT, recipient TEXT, status TEXT);  #@13
CREATE TABLE IF NOT EXISTS scheduled (id TEXT PRIMARY KEY, channel TEXT, recipient TEXT, subject TEXT, body TEXT, send_at TEXT);  #@17
CREATE TABLE IF NOT EXISTS disabled_templates (name TEXT PRIMARY KEY);  #@22
"""

_conn = None


def connect(path=DB_PATH):
    """Open the database once per process and create the tables."""
    global _conn
    if _conn is None:
        _conn = sqlite3.connect(path, check_same_thread=False)
        _conn.executescript(SCHEMA)
    return _conn
  #@19
  #@19
def _one(sql, args):  #@19
    row = connect().execute(sql, args).fetchone()  #@19
    return row[0] if row else None  #@19
  #@6
  #@6
def sent_since(recipient, since):  #@6
    """How many messages recipient has been sent since the given time."""  #@6
    return connect().execute("SELECT COUNT(*) FROM sends WHERE recipient = ? AND at > ?", (recipient, since)).fetchone()[0]  #@6-19
    return _one("SELECT COUNT(*) FROM sends WHERE recipient = ? AND at > ?", (recipient, since))  #@19
  #@6
  #@6
def allow(recipient, now=None):  #@6
    """Count a send to recipient; False once it has had RATE_LIMIT sends in the window."""  #@6
    now = now or time.time()  #@6
    if sent_since(recipient, now - RATE_WINDOW_SECONDS) >= RATE_LIMIT:  #@6
        return False  #@6
    db = connect()  #@6
    db.execute("INSERT INTO sends VALUES (?, ?)", (recipient, now))  #@6
    db.commit()  #@6
    return True  #@6
  #@7
  #@7
def unsubscribed(recipient):  #@7
    return connect().execute("SELECT 1 FROM unsubscribes WHERE recipient = ?", (recipient,)).fetchone() is not None  #@7-19
    return _one("SELECT 1 FROM unsubscribes WHERE recipient = ?", (recipient,)) is not None  #@19
  #@9
  #@9
def seen(key):  #@9
    return connect().execute("SELECT 1 FROM idempotency_keys WHERE key = ?", (key,)).fetchone() is not None  #@9-19
    return _one("SELECT 1 FROM idempotency_keys WHERE key = ?", (key,)) is not None  #@19
  #@9
  #@9
def remember(key):  #@9
    db = connect()  #@9
    db.execute("INSERT OR IGNORE INTO idempotency_keys VALUES (?, ?)", (key, time.time()))  #@9
    db.commit()  #@9
  #@13
  #@13
def record(message_id, channel, recipient):  #@13
    db = connect()  #@13
    db.execute("INSERT INTO messages VALUES (?, ?, ?, 'sent')", (message_id, channel, recipient))  #@13
    db.commit()  #@13
  #@13
  #@13
def get(message_id):  #@13
    row = connect().execute("SELECT id, channel, recipient, status FROM messages WHERE id = ?", (message_id,)).fetchone()  #@13
    return dict(zip(("id", "channel", "recipient", "status"), row)) if row else None  #@13
  #@17
  #@17
def schedule(message_id, channel, recipient, subject, body, send_at):  #@17
    db = connect()  #@17
    db.execute(  #@17
        "INSERT INTO scheduled VALUES (?, ?, ?, ?, ?, ?)",  #@17
        (message_id, channel, recipient, subject, body, send_at.isoformat()),  #@17
    )  #@17
    db.commit()  #@17
  #@22
  #@22
def template_disabled(name):  #@22
    return _one("SELECT 1 FROM disabled_templates WHERE name = ?", (name,)) is not None  #@22
PY

IFS= read -r -d '' SERVER <<'PY' || true
"""Serve the API with the standard library's HTTP server."""

import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from notify.api import handle


class Handler(BaseHTTPRequestHandler):
    def _respond(self):
        raw = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        status, body = handle(self.command, self.path, raw)
        payload = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    do_GET = do_POST = _respond


if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", 8025), Handler).serve_forever()
PY

IFS= read -r -d '' ERRORTESTS <<'PY' || true
import unittest

from notify import errors


def all_codes():
    return [v for v in vars(errors).values() if isinstance(v, errors.ErrorCode)]


class ErrorCodeTest(unittest.TestCase):
    def test_codes_are_unique(self):  #@15
        codes = [e.code for e in all_codes()]  #@15
        self.assertEqual(len(codes), len(set(codes)))  #@15
  #@15
    def test_statuses_are_errors(self):
        for e in all_codes():
            self.assertTrue(400 <= e.status < 600, e)

    def test_messages_are_sentences(self):
        for e in all_codes():
            self.assertTrue(e.message[:1].isupper() and e.message.endswith("."), e)

    def test_response_carries_detail(self):
        status, body = errors.response(errors.UNKNOWN_TEMPLATE, "welcome")
        self.assertEqual((status, body["error"], body["detail"]), (404, "unknown_template", "welcome"))

    def test_response_without_detail(self):
        self.assertNotIn("detail", errors.response(errors.INVALID_JSON)[1])


if __name__ == "__main__":
    unittest.main()
PY

IFS= read -r -d '' TEMPLATETESTS <<'PY' || true
import unittest
from unittest import mock  #@22

from notify import errors, templates


class RenderTest(unittest.TestCase):
    def test_fills_variables(self):  #@5-22
    @mock.patch("notify.store.template_disabled", return_value=False)  #@22
    def test_fills_variables(self, _):  #@22
        subject, body = templates.render("welcome", {"name": "Ada"})
        self.assertEqual(subject, "Welcome, Ada")
        self.assertIn("Ada", body)

    def test_names_missing_variable(self):  #@5-22
    @mock.patch("notify.store.template_disabled", return_value=False)  #@22
    def test_names_missing_variable(self, _):  #@22
        with self.assertRaises(errors.ApiError) as caught:
            templates.render("welcome", {})
        self.assertEqual(caught.exception.detail, "name")


if __name__ == "__main__":
    unittest.main()
PY

IFS= read -r -d '' README <<'MD' || true
# notify

Sends templated messages by email and SMS.

    POST /messages  {"template": "welcome", "to": ["ada@example.com"], "variables": {"name": "Ada"}}

Errors come back as `{"error": "<code>", "message": "..."}`; every code is
listed in `notify/errors.py`.

## Running it locally  #@11
  #@11
Python 3.11 or later, standard library only:  #@11
  #@11
    python3 -m unittest discover -s tests  #@11
    python3 -m notify.server  #@11
MD

cat > notify/templates/en/welcome.txt <<'TXT'
Welcome, {name}

Thanks for signing up, {name}. You can change which messages you get at any time.
TXT

commit 1 330 alex "Send email from templates"
commit 2 318 alex "Require a recipient"
commit 3 309 dana "Validate email addresses"
commit 4 297 dana "Send SMS through the gateway"
commit 5 285 alex "Name the missing template variable in the error"
commit 6 274 kofi "Rate limit messages per recipient"
commit 7 262 kofi "Honour unsubscribes"
commit 8 250 dana "Don't send texts during quiet hours"
commit 9 241 alex "Idempotency keys for POST /messages"
commit 10 229 dana "Reject texts over 1600 characters"
commit 11 220 kofi "README: running it locally"
commit 12 208 alex "Reject unknown channels"
commit 13 196 alex "GET /messages/<id>"
commit 14 183 kofi "Answer 503 when the relay or the SMS gateway is down"
commit 15 170 dana "Test that error codes are unique"
commit 16 158 dana "Limit attachment size"
commit 17 144 kofi "Scheduled sends"
cat > notify/templates/de/welcome.txt <<'TXT'
Willkommen, {name}

Danke für deine Anmeldung, {name}. Welche Nachrichten du bekommst, kannst du jederzeit ändern.
TXT
commit 18 131 alex "German templates"
commit 19 117 kofi "Tidy store queries"
commit 20 103 dana "Batch sends of up to 100 recipients"
commit 21 88 alex "Send only from verified sender addresses"
commit 22 71 kofi "Switch a template off without deleting it"
commit 23 52 dana "Give the SMS gateway longer to answer"
commit 24 30 alex "Explain quiet hours in the error message"
commit 25 12 kofi "POST /previews renders a template without sending it"
