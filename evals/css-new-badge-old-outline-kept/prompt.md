---
description: "A stylesheet that has long removed focus outlines in a legacy rule gets an uncommitted, correct change adding a status badge. The CSS reviewer reviews the diff, lists the old outline removal only as pre-existing if at all, and reports nothing High against the change."
expected_outcome: "The review attributes no High or Critical finding to the change, and doesn't present the legacy outline removal as a defect the change introduced; with the plugin, the CSS reviewer ran."
tags: [css-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Quick one: added a status badge style for the order table. Can you review my uncommitted CSS? I can't open files on this machine, so put the full review in your reply, exactly as written.
