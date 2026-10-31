---
description: An uncommitted change to an agent Collector's configuration adds a redaction processor that masks email addresses, under a comment saying customer emails must be stripped before telemetry leaves the network, but the traces pipeline still lists only memory_limiter and batch. The processor never runs, so emails still reach the hosted backend, and the OpenTelemetry skill's review reports that as High, Critical or blocking.
expected_outcome: The review says the redaction processor isn't in any pipeline, so it does nothing and emails are still exported, and rates it High, Critical or blocking.
tags: [opentelemetry, otel-holdout]
runs: 1
max_turns: 20
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Skill]
---

Review my uncommitted Collector change. I can't open files on this machine, so put everything in your reply.
