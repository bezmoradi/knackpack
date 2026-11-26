---
description: The user asks for a proper fix to a strict-mode TypeScript error. Changing TypeScript starts the TypeScript engineering skill on its own; the TypeScript reviewer, which reviews only when asked, doesn't start.
expected_outcome: The typescript-engineering skill loads, and the knackpack TypeScript reviewer never runs.
tags: [trigger, "starts:knackpack:typescript-engineering", "quiet:knackpack:typescript-code-reviewer"]
runs: 1
max_turns: 20
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Edit, Agent, Skill]
---

`npm run typecheck` fails on src/prices.ts with "'perSeat' is possibly 'undefined'" on the `perSeat * seats` line. Can you fix it properly? I don't want a `!` slapped on it.
