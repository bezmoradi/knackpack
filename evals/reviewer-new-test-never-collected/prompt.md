---
description: An uncommitted fix changes proration to round half a cent up and adds a regression test in tests/proration_rounding_test.py, but pyproject.toml limits pytest to files named test_*.py, so the new test is never collected and a green pytest run says nothing about the fix. The adversarial reviewer reports that the regression test doesn't run.
expected_outcome: The review reports that tests/proration_rounding_test.py doesn't match python_files = ["test_*.py"], so pytest never collects it and the fix has no running regression test, and suggests renaming the file (or adding the test to tests/test_proration.py); it doesn't treat "pytest passes" as evidence for the fix; with the plugin, the adversarial reviewer ran.
tags: [reviewer, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

I fixed the half-cent proration rounding bug and added a regression test, and pytest is green. Do an adversarial review of my uncommitted changes before I merge. I can't open files on this machine, so put the full review in your reply, exactly as written.
