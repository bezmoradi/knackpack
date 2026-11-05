---
description: "A volunteer rota service that lints with typescript-eslint's type-aware rules bumps typescript from ~5.9.3 to ^7.0.2 and changes nothing else. typescript-eslint 8.72.1 declares a typescript peer range of >=4.8.4 <6.1.0 because TypeScript 7 ships no compiler API, so npm install fails with ERESOLVE in CI, and with --legacy-peer-deps ESLint aborts with 'typescript-eslint does not support TS 7.0'. tsc 7.0.2 itself type-checks the code cleanly. The reviewer reports the tooling incompatibility."
expected_outcome: "The review reports that typescript-eslint 8.x doesn't support TypeScript 7 (its peer range stops below 6.1, or TS 7 has no compiler API for it), so the install or the lint step in CI fails, names a fix such as keeping TypeScript 6 for linting through the @typescript/typescript6 alias or staying on 5.9 or 6.0 until typescript-eslint supports 7, and grades it Medium or higher; with the plugin, the reviewer ran."
tags: [ts-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Moved the rota service to TypeScript 7, the type check is so much quicker now. Can you review my uncommitted TypeScript changes before I push? I can't open files on this machine, so put the full review in your reply, exactly as written.
