---
description: A notes service behind PgBouncer in transaction mode relies on row-level security that reads app.workspace_id. The change moves setting it from each transaction, with set_config(..., true), to once per request with set_config(..., false) on an autocommit connection. Through transaction pooling the session setting stays on whichever server connection ran it, and the request's later transactions run on connections carrying other requests' workspaces, so notes are read and written across workspaces. The review should catch that.
expected_outcome: The review reports that the session-level workspace setting doesn't follow the request's transactions through PgBouncer's transaction pooling, so requests can read or change another workspace's notes, rates it High, Critical or blocking, and suggests setting it transaction-locally in each transaction again.
tags: [database, database-reviewer, database-holdout, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Quick perf tweak: I set the workspace once per request instead of in every transaction, to save a round trip. Mind reviewing the uncommitted change? I can't open files on this machine, so put the full review in your reply, exactly as written.
