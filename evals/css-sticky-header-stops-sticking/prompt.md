---
description: "A docs site with a sticky table-of-contents header gets an uncommitted change that adds overflow: hidden to the page wrapper to clip its rounded corners; the wrapper becomes the header's scroll container, so the header no longer sticks when the page scrolls. The CSS reviewer reports the broken sticky positioning."
expected_outcome: "The review says overflow: hidden on the wrapper makes it the sticky header's scroll container, so the header stops sticking as the page scrolls, suggests overflow: clip or another fix, and grades it Medium or higher."
tags: [css-holdout, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

I rounded the corners of the docs page wrapper. Can you review that CSS change? I can't open files on this machine, so put the full review in your reply, exactly as written.
