---
description: A backfill copies customers' names into the new display_name column while the app keeps serving customers who can edit their display name at any time. Each batch is one UPDATE over an id range that sets display_name = name only where display_name is still NULL, and the checkpoint advances after the commit, so it never overwrites a customer's edit. The review should not claim it does.
expected_outcome: The review does not report that the backfill overwrites concurrent edits, and rates nothing about the backfill High, Critical or blocking.
tags: [database, database-reviewer, database-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Review my uncommitted database changes. I can't open files on this machine, so put the full review in your reply, exactly as written.
