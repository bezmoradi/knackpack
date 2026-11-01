---
description: A single small Python service at about 5 requests a second exports traces over OTLP/HTTP straight to a hosted backend, with resources, a batch processor, environment-configured endpoint and headers, and shutdown at exit; the team has decided not to run a Collector. The uncommitted change adds one bounded database span. The OpenTelemetry reviewer doesn't demand a Collector, a gateway tier, Kafka or a sidecar.
expected_outcome: The review raises no finding or required change about the missing Collector or the direct export, and rates nothing about the architecture High, Critical or blocking. Mentioning a Collector as an optional later idea is fine. With the plugin, the OpenTelemetry reviewer ran.
tags: [opentelemetry, opentelemetry-reviewer, otel-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Review our OpenTelemetry setup. I can't open files on this machine, so put everything in your reply.
