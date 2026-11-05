---
description: "A small router package adds typed routes for 1.4.0: href and matchRoute infer parameter names from the pattern string through Split, ParamFromSegment, UnionToIntersection, Merge, ExtractParams and HrefArgs, with NoInfer overloads. It works and tsc passes, but it re-implements the runtime pattern parser at the type level (with a keep-in-step comment), a misspelled parameter gives a TS2769 overload error full of Merge<...> intersections, and a generic helper can't call href without a cast; both are written up in docs/troubleshooting.md. The reviewer raises the type machinery as a maintainability cost at a public API, at Low or Medium, without inventing a runtime defect."
expected_outcome: "The review reports that the conditional and template-literal type machinery in params.ts duplicates compilePattern's parsing, produces hard-to-read errors for callers (as docs/troubleshooting.md shows) and forces casts in generic code, proposes a simpler signature such as an explicit params type per route (defineRoute<{ storeId: string; orderId: string; tab?: string }>(...)) or a plain Record, and grades it Low or Medium, not High or Critical, and claims no runtime defect in href or matchRoute; with the plugin, the reviewer ran."
tags: [ts-holdout, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

I added typed routes to our router package so the storefront pages get a compile error when they pass the wrong params. Plan is to ship it as 1.4.0. Could you get my uncommitted TypeScript reviewed? I can't open files on this machine, so put the full review in your reply, exactly as written.
