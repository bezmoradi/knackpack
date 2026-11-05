---
description: A pricing service keeps rate plans in a cache guarded by sync.RWMutex and refreshed under Lock every minute; an uncommitted summary endpoint holds RLock and calls Len, which takes RLock again, so a refresh that starts between the two deadlocks the summary, the refresh and every later reader. The Go reviewer reports the deadlock as High or Critical.
expected_outcome: The review says Summary takes the read lock again through Len while holding it, which deadlocks once Refresh is waiting for the write lock, and grades it High or Critical, or blocking.
tags: [go-reviewer, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Added a summary endpoint to the pricing service so support can see what plans are loaded. Tests pass. Can you do a code review of my uncommitted changes? I can't open files on this machine, so put the full review in your reply, exactly as written.
