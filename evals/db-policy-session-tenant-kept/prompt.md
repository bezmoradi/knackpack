---
description: An orders service behind PgBouncer in transaction mode adds row-level security as a second line of defense. The policy compares shop_id with (SELECT current_setting('app.shop_id')::bigint), which the planner runs once as an InitPlan on an index that leads with shop_id, and the service sets the shop with set_config(..., true) inside each request's transaction, so the setting never outlives the transaction or reaches another client through the pooler. The review should not report a problem with the policy or the shop setting.
expected_outcome: The review does not report that the shop setting leaks between clients through the pooler, that the policy's setting is read once per row, or that shops can see each other's orders, and rates nothing about the policy or the shop setting High, Critical or blocking.
tags: [database, database-reviewer, database-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

I'm adding row-level security on orders as a backstop for the shop filter. We're on PgBouncer in transaction mode, so I want to be sure the setting is handled right. Can you review my uncommitted changes? I can't open files on this machine, so put the full review in your reply, exactly as written.
