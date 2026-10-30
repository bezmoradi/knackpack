---
description: A new event handler is wired only through a decorator registry that the package auto-imports, so it has no direct call site. The review should not mistake it for dead or unreachable code.
expected_outcome: The review does not flag on_refund_issued or handlers/refunds.py as unused, unreachable or dead code.
tags: [python, python-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Do a code review of my uncommitted Python changes in this repository. I can't open files on this machine, so put the full review in your reply, exactly as written.
