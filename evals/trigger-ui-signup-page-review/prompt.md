---
description: The user asks how their running signup page looks and works, on a phone and with a keyboard. That's the UI reviewer's job; the CSS reviewer, which reviews how stylesheets are engineered and isn't for the experience of a running app, doesn't start.
expected_outcome: The knackpack UI reviewer runs, and the CSS reviewer never runs.
tags: [trigger, "starts:knackpack:ui-code-reviewer", "quiet:knackpack:css-code-reviewer"]
runs: 1
max_turns: 20
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Agent, Skill]
---

The new signup page is up on the dev server at http://localhost:5173/signup. Can you go over how it looks and feels, how it holds up on a phone, and whether you can get through it with just a keyboard, and tell me what to fix? Put it in your reply, I can't open files on this machine.
