---
description: The adversarial reviewer finds a missing tenant check that the uncommitted change adds, grades it High or Critical, and ends with the findings table.
expected_outcome: The report names update_order_status, says it lets a caller change another tenant's order, and lists it in the findings table as High or Critical.
tags: [reviewer, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Do an adversarial review of my uncommitted changes in this repository: try to break them, and report only problems you can show. I can't open files on this machine, so put the full review in your reply, exactly as written.
