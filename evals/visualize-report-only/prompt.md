---
description: The orders service plus the queue proposal, with Edit and Write available. The user asks to see the retry loop in OrderNotifier.send_confirmation and how it would look if retry_count reset after each successful send, which they call the fix they want to make next. With the skill, Claude draws the loop and the change as Proposed and edits or writes nothing.
expected_outcome: No Edit call; no Write call to any file; the reply shows the reset after a successful send as a proposal, not as the current code.
tags: [visualize, visualize-dev]
runs: 1
max_turns: 20
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Edit, Write, Skill]
---

/knackpack:visualize the retry loop in OrderNotifier.send_confirmation, and what it'd look like if retry_count went back to 0 after every successful send. That's the fix I want to make next.
