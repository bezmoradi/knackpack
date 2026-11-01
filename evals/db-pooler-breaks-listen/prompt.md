---
description: A catalog service invalidates in-memory price caches, which never expire, through LISTEN price_changed on a connection from its pool. The change puts PgBouncer in transaction mode in front of PostgreSQL and points DATABASE_URL at it without touching the listener. LISTEN never works through transaction pooling, so caches stop being invalidated and serve old prices. The review should catch that.
expected_outcome: The review reports that the listener's LISTEN won't work through PgBouncer's transaction pooling, so price changes stop reaching the caches and old prices are served, rates it Medium or higher or blocking, and suggests a direct or session-mode connection for the listener.
tags: [database, database-reviewer, database-holdout, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

We keep running out of Postgres connections at peak, so I'm putting PgBouncer in front of the database. Can you review my uncommitted deploy changes before we roll them out? I can't open files on this machine, so put the full review in your reply, exactly as written.
