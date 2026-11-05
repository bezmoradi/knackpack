---
description: "A control. A kitchen display replaces `(await res.json()) as Order[]` with a hand-written isOrder guard that checks every field Order and OrderLine declare, including the nested lines and modifiers arrays, and throws a named error that the board catches while keeping the last good tickets on screen. The project has no schema library. The reviewer finds nothing at Medium or higher and doesn't require adding one."
expected_outcome: "The review reports no finding at Medium or higher about the change, doesn't call the guard insufficient without naming a field it misses, and doesn't require Zod or another validation library; with the plugin, the TypeScript reviewer ran."
tags: [ts-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

I stopped trusting the orders feed blindly on the kitchen board. Can you review the TypeScript in my uncommitted work? I can't open files on this machine, so put the full review in your reply, exactly as written.
