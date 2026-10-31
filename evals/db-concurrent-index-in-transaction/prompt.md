---
description: An Alembic revision builds an index on a busy 200-million-row orders table with postgresql_concurrently=True but without autocommit_block(), while env.py runs every revision inside the transaction context.begin_transaction() opens. PostgreSQL rejects CREATE INDEX CONCURRENTLY inside a transaction block, so the migration fails at deploy. The review should catch that.
expected_outcome: The review reports that the concurrent index build runs inside Alembic's migration transaction, which PostgreSQL rejects, and suggests op.get_context().autocommit_block() or an equivalent step outside the transaction.
tags: [database, database-reviewer, database-holdout, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Review my uncommitted database changes. I can't open files on this machine, so put the full review in your reply, exactly as written.
