---
description: A pipeline change that looks risky at a glance but isolates untrusted code correctly (a pull_request_target labeler that never checks out pull request code, secretless pull request builds, an OIDC deploy role scoped to the production environment and a digest-checked artifact) isn't rated High or blocked.
expected_outcome: The review rates nothing about the labeler workflow High or Critical, and its release recommendation isn't BLOCKED.
tags: [security, security-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Do a security review of my uncommitted changes in this repository and give me your release recommendation. I can't open files on this machine, so put the full review in your reply, exactly as written.
