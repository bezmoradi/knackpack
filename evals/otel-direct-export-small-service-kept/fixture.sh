#!/bin/bash
# A single small Python service, orders-api, that answers order lookups from
# SQLite at about 5 requests a second and exports traces over OTLP/HTTP
# straight to a hosted backend; the README records that the team decided not
# to run a Collector. The uncommitted change adds one database span with a
# bounded name. Exporting directly is a valid choice here, not a defect.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"

cat > pyproject.toml <<'EOF'
[project]
name = "orders-api"
version = "2.3.0"
requires-python = ">=3.11"
dependencies = [
    "opentelemetry-sdk~=1.45.0",
    "opentelemetry-exporter-otlp-proto-http~=1.45.0",
]
EOF

cat > README.md <<'EOF'
# orders-api

One small service that answers order lookups from a local SQLite database. It
handles about 5 requests a second.

    ORDERS_DB=/var/lib/orders/orders.db python app.py

## Telemetry

Traces go straight from the service to our hosted tracing backend over
OTLP/HTTP. The deployment sets `OTEL_EXPORTER_OTLP_ENDPOINT` to the backend's
ingest URL and `OTEL_EXPORTER_OTLP_HEADERS` to its API key header, from the
secret store. This is our only service, and we've decided not to run an
OpenTelemetry Collector: at this volume we don't want another component to
deploy and watch.
EOF

# app.py is written in three parts, so the change below replaces only
# find_order.
app_head() {
	cat <<'EOF'
"""orders-api: answers order lookups from a local SQLite database."""

import atexit
import json
import os
import signal
import sqlite3
import sys
from contextlib import closing
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlsplit

from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

SERVICE_VERSION = "2.3.0"
DB_PATH = os.environ.get("ORDERS_DB", "orders.db")
PORT = int(os.environ.get("PORT", "8000"))

tracer = trace.get_tracer("orders_api")


def init_tracing():
    """Export spans over OTLP/HTTP. The exporter reads the endpoint from
    OTEL_EXPORTER_OTLP_ENDPOINT and its headers from OTEL_EXPORTER_OTLP_HEADERS."""
    resource = Resource.create(
        {"service.name": "orders-api", "service.version": SERVICE_VERSION}
    )
    # Shut the provider down once, from our own atexit hook, so the last batch
    # is exported before the process ends.
    provider = TracerProvider(resource=resource, shutdown_on_exit=False)
    provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))
    trace.set_tracer_provider(provider)
    atexit.register(provider.shutdown)


def query_orders(status):
    sql = "SELECT id, status, total_cents FROM orders"
    params = ()
    if status:
        sql += " WHERE status = ?"
        params = (status,)
    with closing(sqlite3.connect(DB_PATH)) as conn:
        rows = conn.execute(sql + " ORDER BY id LIMIT 100", params).fetchall()
    return [{"id": r[0], "status": r[1], "total_cents": r[2]} for r in rows]


EOF
}
app_tail() {
	cat <<'EOF'
class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        url = urlsplit(self.path)
        parts = url.path.strip("/").split("/")
        if parts == ["orders"]:
            self.list_orders(parse_qs(url.query).get("status", [None])[0])
        elif len(parts) == 2 and parts[0] == "orders" and parts[1]:
            self.get_order(parts[1])
        else:
            self.send_json(404, {"error": "not found"})

    def list_orders(self, status):
        with tracer.start_as_current_span(
            "GET /orders", kind=trace.SpanKind.SERVER
        ) as span:
            span.set_attribute("http.request.method", "GET")
            span.set_attribute("http.route", "/orders")
            rows = query_orders(status)
            span.set_attribute("http.response.status_code", 200)
            self.send_json(200, rows)

    def get_order(self, order_id):
        with tracer.start_as_current_span(
            "GET /orders/{id}", kind=trace.SpanKind.SERVER
        ) as span:
            span.set_attribute("http.request.method", "GET")
            span.set_attribute("http.route", "/orders/{id}")
            order = find_order(order_id)
            code = 200 if order else 404
            span.set_attribute("http.response.status_code", code)
            self.send_json(code, order or {"error": "not found"})

    def send_json(self, code, body):
        data = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)


def main():
    init_tracing()
    # Turn SIGTERM into a normal exit, so the atexit hook flushes the spans.
    signal.signal(signal.SIGTERM, lambda signum, frame: sys.exit(0))
    server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    try:
        server.serve_forever()
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
EOF
}
{
	app_head
	cat <<'EOF'
def find_order(order_id):
    with closing(sqlite3.connect(DB_PATH)) as conn:
        row = conn.execute(
            "SELECT id, status, total_cents FROM orders WHERE id = ?", (order_id,)
        ).fetchone()
    if row is None:
        return None
    return {"id": row[0], "status": row[1], "total_cents": row[2]}


EOF
	app_tail
} >app.py

git add -A
git commit -qm "orders-api with traces exported straight to the hosted backend"

# The change: one client span around the lookup query, named by operation and
# table rather than by the query or the order ID.
{
	app_head
	cat <<'EOF'
def find_order(order_id):
    with tracer.start_as_current_span(
        "SELECT orders",
        kind=trace.SpanKind.CLIENT,
        attributes={
            "db.system.name": "sqlite",
            "db.operation.name": "SELECT",
            "db.collection.name": "orders",
        },
    ):
        with closing(sqlite3.connect(DB_PATH)) as conn:
            row = conn.execute(
                "SELECT id, status, total_cents FROM orders WHERE id = ?",
                (order_id,),
            ).fetchone()
    if row is None:
        return None
    return {"id": row[0], "status": row[1], "total_cents": row[2]}


EOF
	app_tail
} >app.py
