---
description: A shop service switches from an in-memory order map to the ledger service through a small LedgerSource adapter. The adapter looks thin, but it turns the ledger's 404 into orders.ErrNotFound, which the handler maps to a 404 response, and maps ledger entries to orders, so the review keeps it.
expected_outcome: LedgerSource isn't called a pass-through or unneeded, and the handler isn't told to call the ledger client directly; with the plugin, the slop reviewer ran.
tags: [slop, slop-dev]
runs: 1
max_turns: 20
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Agent]
---

The task was to load orders from the ledger service instead of the in-memory map the prototype used. My uncommitted change adds orders/ledger.go and wires it up in cmd/shop/main.go. Check it for slop: anything it adds that we don't need.

I can't open files on this machine, so put the full review in your reply, exactly as written.
