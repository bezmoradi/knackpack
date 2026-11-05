---
description: "The change moves checkout to a carrier's v2 quotes, edits the project's own global declaration file src/types/parcelway.d.ts so Quote.price is Money, a name that isn't in scope there, and adds skipLibCheck: true to tsconfig. skipLibCheck skips the project's own .d.ts files too, so the TS2304 disappears and price becomes an error type that behaves as any; shippingChargeCents then reads quote.price.cents, which doesn't exist, and every checkout shows shipping and total as $NaN. The reviewer reports what skipLibCheck hides here and the any it lets through."
expected_outcome: "The review reports that skipLibCheck also skips the project's own src/types/parcelway.d.ts, hiding a real error there (Money isn't defined or imported in that global declaration file), so Quote.price silently becomes any and the compiler no longer checks its uses, letting quote.price.cents (the field is amountCents) produce NaN shipping and totals; it recommends fixing the declaration (import the type) instead of turning on skipLibCheck, and grades it Medium or higher; with the plugin, the reviewer ran."
tags: [ts-holdout, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Moved checkout over to Parcelway's v2 quotes before they turn v1 off, and the build is green again. Could you review the TypeScript in what I haven't committed? I can't open files on this machine, so put the full review in your reply, exactly as written.
