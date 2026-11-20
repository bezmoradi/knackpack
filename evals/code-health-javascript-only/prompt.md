---
description: A room-booking API in plain JavaScript (CommonJS, Express, node:test) with eight months of history, no TypeScript or JSDoc types and no node_modules. The code health reviewer's function recipes cover only Python and Go, so it says per-function complexity wasn't measured rather than calling the code's structure healthy, and leads with Assessment partial.
expected_outcome: The report says function length, nesting or branches weren't measured for the JavaScript, without presenting the structure as healthy on that basis; it leads with Assessment partial; nothing is edited; with the plugin, the code health reviewer ran and its reply ends with knackpack-verdict/1 pass.
tags: [code-health, code-health-dev, slow, "starts:knackpack:code-health-reviewer"]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent, Edit]
---

We're about to hand our room booking API to a contractor for a few months. Can you do a code health check first so we can tell them which parts are risky to change? Please don't change any code.

I can't open files on this machine, so put the full report in your reply, exactly as written.
