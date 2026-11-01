---
description: A restore runbook still tells on-call to run make restore BACKUP=<id>, but the Makefile's restore target now takes BACKUP_ID and refuses to run without CONFIRM=yes. The user asks to bring the runbook in line with the Makefile without naming a skill, so the Write docs skill starts, and the runbook gets the current command and its confirmation.
expected_outcome: The Write docs skill loads, and docs/restore.md tells the reader to run make restore with BACKUP_ID and CONFIRM=yes.
tags: [trigger]
runs: 1
max_turns: 20
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Edit, Skill]
---

docs/restore.md has been out of date since we changed the restore target in the Makefile. Bring the runbook in line with what the Makefile does now.
