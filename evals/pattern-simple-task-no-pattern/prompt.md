---
description: Adding a verbose flag to a small Go CLI is an ordinary change. No knackpack reviewer starts, no pattern is introduced, and the flag is added.
expected_outcome: main.go gains a verbose flag; no knackpack reviewer starts.
tags: [pattern, pattern-dev, quick]
max_turns: 20
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Edit, Agent]
---

Add a -verbose flag to the CLI that prints each file name to stderr as it's counted.
