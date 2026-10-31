---
description: An Alembic revision builds an index on a busy 200-million-row orders table concurrently inside op.get_context().autocommit_block(), after setting a lock_timeout, and the downgrade drops it concurrently in an autocommit block too. The concurrent build runs outside Alembic's migration transaction as PostgreSQL requires, so the review should not claim it fails inside a transaction.
expected_outcome: The review does not report that the index build fails inside a transaction, and rates nothing about the index migration High, Critical or blocking.
tags: [database, database-reviewer, database-holdout, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Review my uncommitted database changes. I can't open files on this machine, so put the full review in your reply, exactly as written.
