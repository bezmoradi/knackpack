---
description: An uncommitted async refund handler calls the coroutine function audit.record without await and answers success, while the audit docs say every refund must be audited before the response; a correctly kept and cancelled metrics task sits nearby. The Python reviewer reports the missing await and rates it serious.
expected_outcome: The review reports that refund never awaits audit.record, so the audit write never runs and refunds go unaudited, and rates it High or Critical, or Medium and blocking; with the plugin, the Python reviewer ran.
tags: [python, python-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Do a code review of my uncommitted Python changes in this repository. I can't open files on this machine, so put the full review in your reply, exactly as written.
