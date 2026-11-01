#!/bin/bash
# A small Python service that already exports traces over OTLP/HTTP, so the
# repository shares the OpenTelemetry reviewer's topic, while the user's question
# is which vendor to pick for dashboards and alerting.
set -euo pipefail
git init -q
git config user.name "Alex Morgan"
git config user.email "alex@example.com"

cat > pyproject.toml <<'EOF'
[project]
name = "orders-api"
version = "1.4.0"
requires-python = ">=3.11"
dependencies = [
    "opentelemetry-sdk~=1.45.0",
    "opentelemetry-exporter-otlp-proto-http~=1.45.0",
]
EOF

cat > README.md <<'EOF'
# orders-api

Answers order lookups for the shop. Traces go over OTLP/HTTP to the endpoint
in OTEL_EXPORTER_OTLP_ENDPOINT. We have no dashboards or alerts yet.
EOF

cat > telemetry.py <<'EOF'
import atexit

from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor


def setup():
    provider = TracerProvider(
        resource=Resource.create({"service.name": "orders-api", "service.version": "1.4.0"})
    )
    provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))
    trace.set_tracer_provider(provider)
    atexit.register(provider.shutdown)
EOF

git add -A
git commit -qm "orders-api with OTLP trace export"
