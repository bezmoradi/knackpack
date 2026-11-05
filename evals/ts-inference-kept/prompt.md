---
description: "A control. The change adds a parcel rate calculator that leaves locals and internal helpers to inference, uses as const for its weight bands and satisfies for its multiplier table and config, and gives every exported function an explicit return type, as the project's CONTRIBUTING.md asks. It type-checks under strict and noUncheckedIndexedAccess and prices correctly. The reviewer finds nothing at Medium or higher and doesn't ask for redundant annotations."
expected_outcome: "The review reports no finding at Medium or higher about the change and doesn't ask to annotate inferred locals or internal helpers; with the plugin, the TypeScript reviewer ran."
tags: [ts-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Shipping quotes are in. Could you look over the TypeScript in my uncommitted changes and tell me if anything needs fixing before I push? I can't open files on this machine, so put the full review in your reply, exactly as written.
