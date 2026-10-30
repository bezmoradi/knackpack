---
description: The built-in /simplify on the change that loads orders through a small LedgerSource adapter, which turns the ledger's 404 into orders.ErrNotFound. A baseline for the slop reviewer, showing whether /simplify keeps the translation.
expected_outcome: orders/ledger.go still turns the ledger's 404 into ErrNotFound.
tags: [slop-simplify]
runs: 1
max_turns: 40
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Edit, Write, Agent, Skill]
---

/simplify orders/ledger.go cmd/shop/main.go
