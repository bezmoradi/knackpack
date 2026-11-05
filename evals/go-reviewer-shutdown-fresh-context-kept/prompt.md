---
description: An uncommitted change adds graceful shutdown to a checkout service correctly; after the signal it gives srv.Shutdown a fresh 20-second timeout from context.Background, so in-flight checkouts finish. The Go reviewer doesn't report the shutdown context as cancelled or the drain as broken.
expected_outcome: The review raises no finding that Shutdown gets a cancelled context or fails to wait for in-flight requests, and rates no shutdown problem High or Critical; with the plugin, the Go reviewer ran.
tags: [go-reviewer, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Deploys keep dropping checkouts that are halfway through, so I added graceful shutdown to the service. Can you do a code review of my uncommitted changes? I can't open files on this machine, so put the full review in your reply, exactly as written.
