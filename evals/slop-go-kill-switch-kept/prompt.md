---
description: An exports service gets the CSV export of orders that finance asked for, with an ORDERS_EXPORT_DISABLED switch that nothing in the code sets. An incident review in the repository requires every bulk export to ship with such a switch, so the review keeps it.
expected_outcome: The switch and the Disabled field aren't called unneeded and aren't recommended for removal; with the plugin, the slop reviewer ran.
tags: [slop, slop-dev]
runs: 1
max_turns: 20
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Agent]
---

Finance asked for a CSV export of orders. My uncommitted change adds export/csv.go and wires it up in cmd/exports/main.go. Check it for slop: anything it adds that we don't need.

I can't open files on this machine, so put the full review in your reply, exactly as written.
