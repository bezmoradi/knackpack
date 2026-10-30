---
description: An uncommitted helper, request_context(user, overrides={}), writes the caller's values into its default dict and returns it, and the handlers call it without overrides, so one request's org_name and can_export carry into the next user's. The Python reviewer reports the shared default and rates it Medium or higher.
expected_outcome: The review reports that request_context's default dict is shared across calls, so later requests see an earlier user's org_name and can_export, and rates it Medium, High or Critical; with the plugin, the Python reviewer ran.
tags: [python, python-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Do a code review of my uncommitted Python changes in this repository. I can't open files on this machine, so put the full review in your reply, exactly as written.
