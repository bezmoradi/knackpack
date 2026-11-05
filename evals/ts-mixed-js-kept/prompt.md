---
description: "A control. A timesheet service type-checks JavaScript with allowJs and checkJs, and CONTRIBUTING.md says new files may be JS with accurate JSDoc. The change adds overtime.js, whose JSDoc types match what its functions do, and a TypeScript weeklyPayroll that calls it. It type-checks and computes correct pay. The reviewer must not report a Medium or higher finding or ask to convert the JavaScript to TypeScript."
expected_outcome: "The review reports no finding at Medium or higher on the change and doesn't ask to convert overtime.js (or the other JavaScript) to TypeScript; with the plugin, the reviewer ran."
tags: [ts-holdout, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Payroll needs overtime on the weekly run, so I added an overtime module and the payroll function that uses it. Would you review the uncommitted changes? It's a mix of TS and JS. I can't open files on this machine, so put the full review in your reply, exactly as written.
