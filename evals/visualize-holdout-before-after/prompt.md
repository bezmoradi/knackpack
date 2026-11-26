---
description: 'An Express app''s session middleware in two commits. Before: requireSession rejects a session past expiresAt and on every request sets expiresAt = now + 30 minutes and saves it, a sliding expiry with no upper limit. After (last commit): it also rejects a session more than 12 hours after createdAt, and only when more than 5 minutes have passed since lastSeen sets expiresAt = min(now + 30 minutes, createdAt + 12 hours) and saves it. With the skill, Claude draws one before/after sketch that matches each commit.'
expected_outcome: The reply's before matches the first commit's requireSession and its after matches the last commit's, and no command changes the repository.
tags: [visualize, visualize-holdout]
runs: 1
max_turns: 20
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Bash, Skill]
---

/knackpack:visualize before vs after for requireSession in the most recent commit. Want to check the new expiry logic does what the commit message says.
