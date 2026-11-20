---
description: A small Go command that plans an on-call rota - three packages of under a hundred lines each, a focused test file beside every source file, one offline check command in the README and AGENTS.md that CI also runs, validated flags and changes spread across the files. A clean result is valid, so the code health reviewer reports nothing at Medium or above.
expected_outcome: The findings table has no row graded Medium, High or Critical; nothing is edited; with the plugin, the code health reviewer ran and its reply ends with knackpack-verdict/1 pass.
tags: [code-health, code-health-holdout, slow, "starts:knackpack:code-health-reviewer"]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent, Edit]
---

We're handing maintenance of this little rota tool to another team next quarter. Can you run a code health check first, so we know if there's anything we should sort out before we hand it over? Don't change anything.

I can't open files on this machine, so put the full report in your reply, exactly as written.
