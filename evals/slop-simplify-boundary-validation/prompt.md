---
description: The built-in /simplify on the change that validates contacts in the handler and again in Store.Add, which the partner CSV import calls directly. A baseline for the slop reviewer, showing whether /simplify keeps the check in Store.Add.
expected_outcome: contacts/store.go still validates in Add.
tags: [slop-simplify]
runs: 1
max_turns: 40
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Edit, Write, Agent, Skill]
---

/simplify contacts/
