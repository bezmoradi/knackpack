---
description: The user asks for a review of an uncommitted stylesheet change. That's a review of CSS, so the CSS reviewer runs; the CSS engineering skill, which guides writing CSS, doesn't load, and the UI reviewer, which judges a running app, doesn't start.
expected_outcome: The knackpack CSS reviewer runs, the css-engineering skill never loads, and the UI reviewer never runs.
tags: [trigger, "starts:knackpack:css-code-reviewer", "quiet:knackpack:css-engineering", "quiet:knackpack:ui-code-reviewer"]
runs: 1
max_turns: 20
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Agent, Skill]
---

I restyled our buttons in styles/buttons.css, it's not committed yet. Can you review the change before I push it? I can't open files on this machine, so put the review in your reply.
