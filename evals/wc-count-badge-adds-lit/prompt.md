---
description: "A published, dependency-free Web Components package whose README promises no runtime dependencies gets an uncommitted count-badge built with Lit, adding lit as a runtime dependency for a static badge that every other component in the package writes on HTMLElement. The reviewer reports the avoidable dependency and the broken promise."
expected_outcome: "The review reports that the change adds lit as a runtime dependency that the package's documented zero-dependency promise rules out and that this static badge doesn't need, since the package's other components extend HTMLElement directly; with the plugin, the reviewer ran."
tags: [wc-holdout, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Added a count-badge to the package, I used Lit since it's quicker to write. Can you review my uncommitted changes? I can't open files on this machine, so put the full review in your reply, exactly as written.
