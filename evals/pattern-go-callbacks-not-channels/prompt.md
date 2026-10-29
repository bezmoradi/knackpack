---
description: A Go event bus delivers to callbacks synchronously, under a copied handler list, with an unsubscribe closure. Asked whether a Go observer should use channels instead, the assessment accepts the callback design and explains why channels are not automatically better.
expected_outcome: The callback bus is judged appropriate for its documented synchronous delivery; a rewrite to channels is not demanded, and the tradeoffs that would make channels fit are named.
tags: [pattern, pattern-holdout]
max_turns: 20
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Agent]
---

events.Bus is an observer built on callbacks. Isn't the Go way to do this with channels? Validate the design and tell me whether it should be rewritten.

I can't open files on this machine, so put the full review in your reply, exactly as written.
