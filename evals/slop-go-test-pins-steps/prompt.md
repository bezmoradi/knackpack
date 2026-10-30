---
description: A tag normalizer comes with tests that record each internal step through a trace hook added for them and assert the steps' order, but never check the normalized tags. The review reports the tests as tied to the implementation and suggests testing inputs against outputs, and grades nothing High.
expected_outcome: The step-order tests (and the trace hook that serves them) are reported, with tests of inputs against expected outputs suggested instead; nothing is graded High or Critical; with the plugin, the slop reviewer ran.
tags: [slop, slop-dev]
runs: 1
max_turns: 20
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Agent]
---

The task was to normalize the tags users type on bookmarks: trim spaces, lowercase them, and drop empty and repeated tags. My uncommitted change adds tags/normalize.go and its tests. Check it for slop: anything it adds that we don't need.

I can't open files on this machine, so put the full review in your reply, exactly as written.
