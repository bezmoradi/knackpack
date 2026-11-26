---
description: The user asks for a hard look at a proposal to move billing into its own service with its own database, where orders and invoices share a transaction today. That's an architecture review; the design pattern reviewer, which judges one abstraction rather than a system's boundaries, doesn't start.
expected_outcome: The knackpack architecture reviewer runs, and the design pattern reviewer never runs.
tags: [trigger, "starts:knackpack:architecture-reviewer", "quiet:knackpack:design-pattern-reviewer"]
runs: 1
max_turns: 20
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Agent, Skill]
---

Before we commit to it, can you give the billing split in docs/billing-split.md a hard look? Is pulling billing out into its own service with its own database the right call, given how orders and invoices are tied together today? Put your review in the reply, I can't open files here.
