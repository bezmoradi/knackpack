---
description: A security review of an MCP server change finds that a new delete tool acts with the server's own service token instead of the caller's authority, and rates it High or Critical.
expected_outcome: The review reports that delete_document deletes with ADMIN_API_TOKEN without checking that the caller owns the document or holds a delete scope, so any authenticated MCP client can delete other users' documents, and rates it High or Critical.
tags: [security, security-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Do a security review of my uncommitted changes in this repository and give me your release recommendation. I can't open files on this machine, so put the full review in your reply, exactly as written.
