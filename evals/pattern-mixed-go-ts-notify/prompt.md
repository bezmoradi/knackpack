---
description: A repository has a Go service that tracks job progress and a TypeScript browser client that renders it. Asked how both should notify dependents of progress changes, the assessment gives each side its own shape and names a semantic difference, instead of one structure for both.
expected_outcome: Per-language recommendations that differ where the semantics differ (goroutines and context versus the event loop and AbortSignal or EventTarget), with the cross-language contract treated separately.
tags: [pattern, pattern-dev]
max_turns: 20
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Agent]
---

Both sides of this repo need the same thing: notify dependents when a job's progress changes. The Go service in jobs/ notifies the HTTP layer, and the TypeScript client in web/ notifies its UI widgets. Select the design for each. Should they use the same pattern so the codebase stays consistent?

I can't open files on this machine, so put the full review in your reply, exactly as written.
