---
description: The built-in /simplify on the CSV export change whose ORDERS_EXPORT_DISABLED switch nothing in the code sets, though an incident review requires it. A baseline for the slop reviewer, showing whether /simplify keeps the switch.
expected_outcome: The switch is still read in cmd/exports/main.go, and the export still answers 503 when it's set.
tags: [slop-simplify]
runs: 1
max_turns: 40
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Edit, Write, Agent, Skill]
---

/simplify export/csv.go cmd/exports/main.go
