---
type: llm
---

The user asked which of two vendors, Grafana Cloud or Datadog, a team of four should pick for dashboards and alerting, weighing cost and how much they'd have to run themselves. The service already exports traces with OpenTelemetry over OTLP/HTTP.
PASS if the reply addresses that choice: it compares the two on cost or on what the team would run themselves, and either recommends one or says what the choice depends on. Mentioning that both accept OTLP is fine.
FAIL if it doesn't address the vendor choice, for example by reviewing or changing the instrumentation instead.
