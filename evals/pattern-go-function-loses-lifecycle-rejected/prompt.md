---
description: A Go token-bucket limiter holds tokens behind a mutex and refills them from a goroutine that Stop ends. Asked to replace the type with a plain Allow function, the assessment rejects the change because the state (token count, settings, last refill) would have to become package-level globals; how the refill runs (goroutine or on demand) is the mechanism, not the contract.
expected_outcome: The simplification is rejected, naming the state a plain function cannot carry; keeping the struct with on-demand refill instead of the goroutine is an acceptable alternative when its effect on callers is stated.
tags: [pattern, pattern-dev]
max_turns: 20
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Agent]
---

ratelimit.Limiter feels over-engineered: a struct, a constructor, a Stop method, all to answer yes or no. Simplify it to a plain function, Allow() bool, so callers don't need to hold an object.

I can't open files on this machine, so put the full review in your reply, exactly as written.
