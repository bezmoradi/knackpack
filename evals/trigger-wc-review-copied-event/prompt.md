---
description: The user asks for a review of an uncommitted change to a custom element. That's a review of Web Components work, so the Web Components reviewer runs; the Web Components engineering skill, which guides writing components, doesn't load.
expected_outcome: The knackpack Web Components reviewer runs, and the web-components-engineering skill never loads.
tags: [trigger, "starts:knackpack:web-components-code-reviewer", "quiet:knackpack:web-components-engineering"]
runs: 1
max_turns: 20
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Agent, Skill]
---

I tidied up the event in src/copy-button.js, it's uncommitted. Could you review it before I cut a release? I can't open files on this machine, so put the review in your reply.
