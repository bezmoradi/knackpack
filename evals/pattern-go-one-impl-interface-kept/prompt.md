---
description: A Go scheduler takes a Clock interface that has one production implementation and a fake in its tests. Asked to drop the interface and call time.Now directly, the assessment keeps an injectable clock because the test boundary justifies it.
expected_outcome: The interface, or an equivalent injectable function, is kept; calling time.Now directly inside the scheduler is not recommended.
tags: [pattern, pattern-dev]
max_turns: 20
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Agent]
---

schedule.Clock has exactly one implementation, realClock. That's an interface for nothing, right? Simplify: should I delete it and have Scheduler call time.Now() directly?

I can't open files on this machine, so put the full review in your reply, exactly as written.
