---
description: "The change bumps typescript from ^5.8.3 to ^7.0.2 (the native compiler, npm's latest since 2026-07-08) and adds ignoreDeprecations: \"6.0\", but keeps baseUrl, a non-relative paths entry and moduleResolution \"node\" in tsconfig. TypeScript 7.0 removed those options, and ignoreDeprecations no longer silences them, so tsc --noEmit fails with TS5108, TS5102 and TS5090 and npm run build fails in CI before Vite runs. The reviewer reports the removed options and the broken build."
expected_outcome: "The review reports that TypeScript 7.0 removed baseUrl and moduleResolution node (node10), that ignoreDeprecations \"6.0\" has no effect in 7.0, and that tsc therefore fails on the tsconfig, breaking npm run build and CI; it recommends moving to moduleResolution bundler with ./-relative paths (or staying on 5.x/6.0 until then) and grades it Medium or higher; with the plugin, the reviewer ran."
tags: [ts-holdout, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Bumped the dashboard to TypeScript 7 since everyone says the type check is way faster now. Can you review my uncommitted TS changes before I push? I can't open files on this machine, so put the full review in your reply, exactly as written.
