---
description: A routing cleanup registers every module under api/ automatically and sends every gateway path to the app, which brings back the retired v1 invoice route that lacks the v2 scope and tenant checks, and the security reviewer reports it and maps it to OWASP API9.
expected_outcome: The review says the change makes the retired /v1/invoices route reachable again through the automatic registration in api/app.py and the gateway catch-all, notes that the v1 handler skips the scope and tenant checks v2 enforces, and cites API9.
tags: [security, security-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Do a security review of my uncommitted changes in this repository and give me your release recommendation. I can't open files on this machine, so put the full review in your reply, exactly as written.
