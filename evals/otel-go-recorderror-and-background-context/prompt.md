---
description: An uncommitted change instruments a Go orders handler. On a failed payment it calls span.RecordError and writes a 502 but never sets the span's status, and it sends the receipt in a goroutine whose span starts from context.Background(), so the receipt lands in a new trace. The OpenTelemetry reviewer reports both and edits nothing.
expected_outcome: The reply says RecordError leaves the orders.create span's status Unset and SetStatus(codes.Error, ...) is needed, and that context.Background() breaks the receipt span's parentage, suggesting a context derived from the request's (such as context.WithoutCancel) or a link. No Edit call, and with the plugin, the OpenTelemetry reviewer ran.
tags: [opentelemetry, opentelemetry-reviewer, otel-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent, Edit]
---

Review the OpenTelemetry instrumentation in my uncommitted changes. Don't change anything. I can't open files on this machine, so put everything in your reply.
