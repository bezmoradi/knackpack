---
description: "A component library whose committed notice-bar and menu-button already have defects (an innerHTML sink and a document listener never removed) gets an uncommitted, correct change adding a size attribute to user-avatar. The reviewer reviews only the change, reports nothing serious against it, and lists the older defects only as pre-existing if at all."
expected_outcome: "The review attributes no High or Critical problem to the change, and presents the committed notice-bar and menu-button defects, if it mentions them, as pre-existing or outside the change; with the plugin, the reviewer ran."
tags: [wc-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Added a size attribute to user-avatar (small, medium, large). Review my uncommitted change please. I can't open files on this machine, so put the full review in your reply, exactly as written.
