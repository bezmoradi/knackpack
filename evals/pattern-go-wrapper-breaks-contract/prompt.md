---
description: A Go logging wrapper around a Store interface replaces the caller's context with context.Background and returns a nil error on failure, while the HTTP handler relies on errors.Is(err, ErrNotFound). The assessment reports both contract breaks as defects with their locations.
expected_outcome: The swallowed error (handler can no longer see ErrNotFound) and the dropped context (cancellation and deadline lost) are both reported as defects at their lines.
tags: [pattern, pattern-dev]
max_turns: 20
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Agent]
---

logging.Store decorates store.Store to add request logging. Validate it: does it preserve the Store contract for the handler in api/?

I can't open files on this machine, so put the full review in your reply, exactly as written.
