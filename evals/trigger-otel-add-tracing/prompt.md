---
description: A Python thumbnail worker already sets up OpenTelemetry tracing in otel_setup.py, and the user asks for one span per job in jobs.py with the image's width and height on it. Adding instrumentation is what the OpenTelemetry reviewer says it isn't for, since it never edits code, so it doesn't start, and jobs.py gets the span.
expected_outcome: The OpenTelemetry reviewer never starts, and jobs.py starts a span for each job.
tags: [trigger]
runs: 1
max_turns: 15
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Edit, Agent]
---

Tracing is already set up in otel_setup.py. Can you add a span around each thumbnail job in jobs.py? One span per job is enough, with the image's width and height as attributes. Keep it small.
