---
description: An invite function replaces SELECT-then-INSERT with INSERT ... ON CONFLICT (email) DO UPDATE to close a race, but the only unique index on email is partial (WHERE deleted_at IS NULL) and the conflict target doesn't repeat its predicate, so PostgreSQL finds no matching constraint and rejects every invite. The review should catch that.
expected_outcome: The review reports that ON CONFLICT (email) doesn't match the partial unique index users_email_live, so every invite fails with an error, rates it High, Critical or blocking, and suggests adding WHERE deleted_at IS NULL to the conflict target.
tags: [database, database-reviewer, database-holdout, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

I swapped the invite lookup for an upsert so two admins inviting the same person can't race. Can you review the uncommitted change? I can't open files on this machine, so put the full review in your reply, exactly as written.
