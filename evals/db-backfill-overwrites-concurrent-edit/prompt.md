---
description: A backfill copies customers' names into the new display_name column while the app keeps serving customers who can edit their display name at any time. It reads a batch of rows whose display_name is NULL, then writes each one with an unconditional UPDATE by id, so an edit made between the read and the write is overwritten. The review should catch that.
expected_outcome: The review reports that the unconditional UPDATE can overwrite a display name a customer set after the batch was read, rates it High, Critical or blocking, and suggests a conditional update such as adding display_name IS NULL to the UPDATE.
tags: [database, database-reviewer, database-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Review my uncommitted database changes. I can't open files on this machine, so put the full review in your reply, exactly as written.
