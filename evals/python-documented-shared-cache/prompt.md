---
description: An uncommitted EUR payout conversion uses a module-level exchange-rate cache that a decision record says is shared on purpose, because the rates are public and the same for every user; keys are immutable tuples, values frozen dataclasses with a TTL, and a lock guards the dict. The Python reviewer doesn't report the cache as a shared-state or thread-safety defect and finds nothing High or Critical.
expected_outcome: The review raises no Medium or higher shared-state, leak or thread-safety finding against the rates cache and nothing High, Critical or blocking; with the plugin, the Python reviewer ran.
tags: [python, python-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Do a code review of my uncommitted Python changes in this repository. I can't open files on this machine, so put the full review in your reply, exactly as written.
