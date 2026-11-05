---
description: "A task list's task-item element is rewritten to build its checkbox and listener in connectedCallback without a guard. Pinning a task moves it with prepend, which disconnects and reconnects it, so it renders a second checkbox and adds a second click listener whose toggle cancels the first. The reviewer reports the non-idempotent connectedCallback."
expected_outcome: "The review reports that connectedCallback runs again when a task is moved (pinned with prepend), duplicating the rendered content and the click listener so the item's toggle stops working or misbehaves, and grades it Medium or higher; with the plugin, the reviewer ran."
tags: [wc-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

I moved task-item's setup out of the constructor into connectedCallback since I read you shouldn't touch children in the constructor. Can you review the uncommitted change? I can't open files on this machine, so put the full review in your reply, exactly as written.
