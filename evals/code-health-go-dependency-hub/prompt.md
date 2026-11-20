---
description: A Go fleet service whose internal/common package holds IDs, money, positions, shifts, errors and formatting helpers; all eight other packages import it, and it changed in 15 of the 22 commits for unrelated reasons. The code health reviewer names it as a dependency hub and gives its fan-in.
expected_outcome: A finding names internal/common as a dependency hub that the other packages import; the report gives its fan-in of 8; nothing is edited; with the plugin, the code health reviewer ran and its reply ends with knackpack-verdict/1 pass.
tags: [code-health, code-health-holdout, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent, Edit]
---

We've got a few months of feature work planned on the fleet service and changes already seem to ripple further than they should. Can you do a code health check and tell me what makes changes spread across the codebase and what we should untangle first? Don't change anything for now.

I can't open files on this machine, so put the full report in your reply, exactly as written.
