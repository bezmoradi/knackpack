---
description: A security review of a change that verifies identity-provider tokens with RS256 reports that RS256 isn't approved cryptography under ASVS, keeps the project's documented exception for it visible as an accepted risk, and doesn't block the release on it.
expected_outcome: The review says RS256 (RSASSA-PKCS1-v1_5) fails ASVS's approved-cryptography requirement and that EXC-007 in docs/security/exceptions.md covers it, names it as a policy exception or accepted risk rather than a met requirement, and its recommendation isn't BLOCKED.
tags: [security, security-holdout, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Do a security review of my uncommitted changes in this repository and give me your release recommendation. I can't open files on this machine, so put the full review in your reply, exactly as written.
