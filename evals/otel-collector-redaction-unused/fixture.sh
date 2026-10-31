#!/bin/bash
# An agent Collector configuration, otel/collector.yaml, that forwards traces
# from the services on a host to a hosted backend. The uncommitted change adds
# a redaction processor to mask customer emails before telemetry leaves the
# network, but leaves the traces pipeline's processors as they were, so the
# processor never runs and emails are still exported.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p otel

cat > README.md <<'EOF'
# host-telemetry

The OpenTelemetry Collector that runs on each application host as a local
agent. The services on the host send OTLP to it over localhost, and it
forwards their traces to the hosted backend at `https://otlp.example.com`.

Hosts run the contrib distribution, otelcol-contrib 0.128.0:

    otelcol-contrib --config=otel/collector.yaml

The backend's API key comes from `BACKEND_API_KEY`, which the host's service
unit reads from the secret store.
EOF

cat > otel/collector.yaml <<'EOF'
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: localhost:4317
      http:
        endpoint: localhost:4318

processors:
  memory_limiter:
    check_interval: 1s
    limit_mib: 400
    spike_limit_mib: 100
  batch: {}

exporters:
  otlphttp:
    endpoint: https://otlp.example.com
    headers:
      x-api-key: ${env:BACKEND_API_KEY}

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlphttp]
EOF

git add -A
git commit -qm "Agent Collector forwarding traces to the hosted backend"

cat > otel/collector.yaml <<'EOF'
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: localhost:4317
      http:
        endpoint: localhost:4318

processors:
  memory_limiter:
    check_interval: 1s
    limit_mib: 400
    spike_limit_mib: 100
  # Customer emails must be stripped before telemetry leaves our network:
  # some services put the customer's email in span attributes.
  redaction:
    allow_all_keys: true
    blocked_values:
      - '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
    summary: info
  batch: {}

exporters:
  otlphttp:
    endpoint: https://otlp.example.com
    headers:
      x-api-key: ${env:BACKEND_API_KEY}

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlphttp]
EOF
