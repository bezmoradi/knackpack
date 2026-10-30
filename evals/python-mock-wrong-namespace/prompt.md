---
description: A new test patches the gateway at its definition module, but the code under test imported the name into its own module, so the patch misses and the real gateway is called. The review should catch the wrong patch target.
expected_outcome: The review reports that the test patches billing.gateway.charge_card rather than billing.charges.charge_card, so the mock is unused and the real gateway runs.
tags: [python, python-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Do a code review of my uncommitted Python changes in this repository. I can't open files on this machine, so put the full review in your reply, exactly as written.
