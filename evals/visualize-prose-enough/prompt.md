---
description: The orders service plus the queue proposal. OrderNotifier.retry_count in orders/notifications.py is set to 0 only in __init__ (line 63) and incremented on each failed attempt (line 78); a successful send returns True without touching it, and the notifier is built once in orders/app.py, so the counter never resets and accumulates across orders for the life of the process. A yes-or-no question, so with the skill Claude answers in prose and says in one line why a visual wouldn't help.
expected_outcome: The reply says the counter does not reset after a successful send, contains no fenced diagram block, and says briefly why it answers without a diagram.
tags: [visualize, visualize-dev]
runs: 1
max_turns: 15
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill]
---

/knackpack:visualize does the retry counter for the confirmation emails reset after a successful send?
