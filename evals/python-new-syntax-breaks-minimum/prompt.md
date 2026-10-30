---
description: A library that declares and tests Python 3.9 adds a function using a match statement, which is a syntax error before 3.10. The review should catch the mismatch with the declared minimum.
expected_outcome: The review reports that the new match statement will not parse on Python 3.9, which the package still supports and runs in CI, without demanding a jump to the newest Python.
tags: [python, python-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Do a code review of my uncommitted Python changes in this repository. I can't open files on this machine, so put the full review in your reply, exactly as written.
