---
description: The user asks for the next SQL migration, an index for a slow page. That's a change to make; knackpack's database reviewer, which reviews only when asked, doesn't start.
expected_outcome: The database reviewer never runs.
tags: [trigger, "quiet:knackpack:database-reviewer"]
runs: 1
max_turns: 20
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Edit, Write, Agent, Skill]
---

The customer order history page is getting slow. Write the next migration in migrations/ adding an index on orders for customer_id and created_at.
