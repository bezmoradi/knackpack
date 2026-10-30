---
description: A document service's Save checks permission before writing, and its tests record the calls and assert that the check runs before the write and that a denied check writes nothing. A decision record in the repository requires exactly those tests, so the review keeps them rather than calling them tied to the implementation.
expected_outcome: The call-order tests aren't called brittle, over-specified or tied to the implementation, and aren't recommended for replacement with result-only tests; with the plugin, the slop reviewer ran.
tags: [slop, slop-dev]
runs: 1
max_turns: 20
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Agent]
---

The task was to add a Save method that stores a document for a signed-in user, but only in folders they may write to. My uncommitted change adds files/service.go and its tests. Check it for slop: anything it adds that we don't need.

I can't open files on this machine, so put the full review in your reply, exactly as written.
