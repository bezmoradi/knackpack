---
description: The user asks for every reviewer that applies to run over their branch together, with one merged list of what to fix. That's Orchestrate review. The case lists no Agent tool, so the reviewers can't start and the run stays cheap; it checks only that the skill is chosen.
expected_outcome: The orchestrate-review skill loads.
tags: [trigger, "starts:knackpack:orchestrate-review"]
runs: 1
max_turns: 10
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill]
---

Before I merge the orders-csv branch, throw every reviewer you've got at it, security, Python, database, whatever applies, and give me one merged list of what to fix rather than a pile of separate reports.
