---
description: A one-file backup-pruning script, dry-run by default, gains a correct --keep option that always retains the N newest backups. The review should match the scope of a standalone script, not demand a package or raise blocking findings.
expected_outcome: The review does not ask for a package layout, pyproject, service architecture or pervasive type hints, and rates nothing High, Critical or blocking.
tags: [python, python-holdout, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Do a code review of my uncommitted Python changes in this repository. I can't open files on this machine, so put the full review in your reply, exactly as written.
