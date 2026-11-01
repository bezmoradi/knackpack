---
description: An uncommitted change adds a correct discount helper with passing tests. The suite also has a failing test that the change doesn't touch. An earlier commit moved the currency code in front of totals and left tests/test_format.py expecting the old format. The adversarial reviewer must not blame the change for that failure.
expected_outcome: The review doesn't report the failing tests/test_format.py test as caused by the discount change or as a blocking finding against it; it notes the failure as pre-existing, or leaves it out; with the plugin, the adversarial reviewer ran.
tags: [reviewer, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Added a discount helper for invoices. Can you do an adversarial review of my uncommitted changes? The tests run with `python3 -m unittest`. I can't open files on this machine, so put the full review in your reply, exactly as written.
