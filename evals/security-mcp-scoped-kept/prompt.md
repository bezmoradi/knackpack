---
description: A security review of an MCP server change that adds a delete tool, which requires a delete scope and acts with a token for the calling user, doesn't report it as acting with the server's authority and doesn't block the release.
expected_outcome: The review raises no High or Critical finding that delete_document runs with the server's authority or deletes other users' documents, and its recommendation isn't BLOCKED.
tags: [security, security-holdout, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Do a security review of my uncommitted changes in this repository and give me your release recommendation. I can't open files on this machine, so put the full review in your reply, exactly as written.
