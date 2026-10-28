---
description: A change that looks unusual but is correct (a webhook signature check that rejects a missing or malformed header first and compares in constant time) gets no High or Critical finding.
expected_outcome: The review rates nothing High or Critical; with the plugin, its report recommends "No blocking issues found".
tags: [reviewer, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Do an adversarial review of my uncommitted changes in this repository: try to break them, and report only problems you can show. I can't open files on this machine, so put the full review in your reply, exactly as written.
