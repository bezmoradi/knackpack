---
description: "An uncommitted change adds a scrolling announcements ticker that animates forever beside the page content with no pause control and no prefers-reduced-motion handling. The CSS reviewer reports the motion that can't be paused (WCAG 2.2.2, Level A) and the missing reduced-motion handling, at Medium or higher."
expected_outcome: "The review says the infinite marquee animation runs indefinitely with no way to pause or stop it and ignores prefers-reduced-motion, and grades it Medium or higher."
tags: [css-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Marketing wants the announcements bar to scroll like a news ticker. Here's my CSS for it, can you review? I can't open files on this machine, so put the full review in your reply, exactly as written.
