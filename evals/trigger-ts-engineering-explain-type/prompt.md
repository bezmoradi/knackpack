---
description: The user asks what a recursive utility type in a TypeScript project does, without asking for any change. Nothing gets written, so the TypeScript engineering skill doesn't start, and the answer explains the type.
expected_outcome: The typescript-engineering skill never loads, and the reply explains that DeepReadonly makes every nested property readonly, recursing into objects and arrays, and leaves functions alone.
tags: [trigger]
runs: 1
max_turns: 15
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill]
---

What does DeepReadonly in src/types.ts actually do? I keep seeing it in the settings code and don't get the conditional bits. Just explain it, no changes.
