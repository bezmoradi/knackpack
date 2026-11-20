---
description: A notification service with a year of history in which notify/errors.py, 49 lines of one-line error code constants with focused tests, changes in 20 of the 25 commits because every feature adds a code. Frequent change alone isn't a hotspot, so the code health reviewer doesn't report errors.py as a hotspot, a complex unit or a risky place to change.
expected_outcome: No finding or recommended step names notify/errors.py as a hotspot, complex unit, large module or risky area; nothing is edited; with the plugin, the code health reviewer ran and its reply ends with knackpack-verdict/1 pass.
tags: [code-health, code-health-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent, Edit]
---

We've been adding features to this service for about a year and it's starting to feel like every change touches half the code. Could you run a code health check and tell me which parts are actually expensive to change and where cleanup time would pay off? Just the report for now, no changes.

I can't open files on this machine, so put the full report in your reply, exactly as written.
