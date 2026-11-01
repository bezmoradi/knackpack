---
description: A hardening migration revokes EXECUTE on the SECURITY DEFINER membership check from the service's role, docs_api, on the belief that row-level security policies don't need it. A policy runs with the privileges of the role running the query, so every query docs_api runs on documents fails with a permission error and the documents API stops working. The review should catch that.
expected_outcome: The review reports that after the revoke every docs_api query on documents fails with permission denied for the function, because the policy runs with the querying role's privileges, rates it High, Critical or blocking, and suggests keeping EXECUTE for docs_api or another fix that keeps the policy working.
tags: [database, database-reviewer, database-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Small follow-up from our security review: I locked down the team membership function so the API can't call it directly. Can you review the uncommitted migration before I ship it? I can't open files on this machine, so put the full review in your reply, exactly as written.
