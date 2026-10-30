---
description: A tiny service keeps all its code in one main package at the module root, and the uncommitted change adds a correct GET /version endpoint. The Go reviewer doesn't ask for cmd/, pkg/, internal/ or layers, and finds nothing High or Critical.
expected_outcome: The review raises no layout finding and nothing High or Critical; with the plugin, the Go reviewer ran.
tags: [go-reviewer, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Do a code review of my uncommitted Go changes in this service. I can't open files on this machine, so put the full review in your reply, exactly as written.
