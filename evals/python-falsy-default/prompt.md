---
description: An uncommitted apply_discount picks the percentage with customer.discount_pct or DEFAULT_DISCOUNT_PCT, while the pricing docs say an explicit 0 means no discount and only None means the default of 10 applies. The Python reviewer reports that an explicit 0 becomes 10%.
expected_outcome: The review reports that the or turns a configured discount_pct of 0 into the 10% default and points to an is None check or equivalent; with the plugin, the Python reviewer ran.
tags: [python, python-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Do a code review of my uncommitted Python changes in this repository. I can't open files on this machine, so put the full review in your reply, exactly as written.
