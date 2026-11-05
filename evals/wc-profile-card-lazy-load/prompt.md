---
description: "A profile page sets the user property on a profile-card element, and an uncommitted change lazy-loads the element's definition with a dynamic import that runs after the assignment. The assignment creates an own data property that shadows the class's setter, so after the upgrade the card never renders the user. The reviewer reports the property lost before upgrade."
expected_outcome: "The review reports that card.user is assigned before profile-card is defined, so the value lands as an own property that shadows the class accessor and the setter never runs after the upgrade, leaving the card empty, and grades it Medium or higher; with the plugin, the reviewer ran."
tags: [wc-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

profile-card was making the first load heavy, so I lazy-load it now. Can you review my uncommitted change? I can't open files on this machine, so put the full review in your reply, exactly as written.
