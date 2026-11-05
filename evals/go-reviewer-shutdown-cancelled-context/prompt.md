---
description: An uncommitted change adds graceful shutdown to a checkout service, but after the signal it passes the signal context, already cancelled, to srv.Shutdown, which then returns at once instead of draining, so main exits over in-flight checkouts on every deploy. The Go reviewer reports it as High or blocking.
expected_outcome: The review says srv.Shutdown receives the signal context after it was cancelled, so it doesn't wait for in-flight requests and main exits over them, and grades it High or Critical, or blocking.
tags: [go-reviewer, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Deploys keep dropping checkouts that are halfway through, so I added graceful shutdown to the service. Can you do a code review of my uncommitted changes? I can't open files on this machine, so put the full review in your reply, exactly as written.
