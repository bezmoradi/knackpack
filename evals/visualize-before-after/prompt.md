---
description: 'A Go checkout package in two commits. Before (first commit): Total adds shipping to the subtotal, takes the discount percent off that sum with no cap and no expiry check, then adds tax on the whole. After (last commit): Total takes a now argument, rejects an expired code with ErrCodeExpired, caps the percent at maxPercent (50), takes it off the items subtotal only, taxes the discounted items, and adds shipping last, untaxed. With the skill, Claude reads both versions from git and draws one before/after sketch that matches each commit.'
expected_outcome: The reply's before matches the first commit's Total and its after matches the last commit's, and no command changes the repository.
tags: [visualize, visualize-dev]
runs: 1
max_turns: 20
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Bash, Skill]
---

/knackpack:visualize before and after for checkout.Total from the last commit. I'm reviewing it and want to see what actually changed in the order of the steps.
