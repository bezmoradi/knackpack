---
description: A new lint workflow that runs only on pull_request with read-only permissions and no secrets, but references actions by tag rather than commit, is treated as hardening advice at most and not as a blocker.
expected_outcome: The review either leaves the tag-referenced actions out or raises them as Low, advisory or nonblocking, and its release recommendation isn't BLOCKED.
tags: [security, security-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Do a security review of my uncommitted changes in this repository and give me your release recommendation. I can't open files on this machine, so put the full review in your reply, exactly as written.
