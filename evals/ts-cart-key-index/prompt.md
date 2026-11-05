---
description: "The uncommitted change adds a per-SKU breakdown to an abandoned-cart report by running quantityBySku[line.sku] += line.quantity on an empty Record<string, number>. Each first read is undefined, so every quantity becomes NaN and the dashboard lists every product as NaN units; tsc accepts it because noUncheckedIndexedAccess is off. The reviewer reports the unsafe indexed access and the NaN."
expected_outcome: "The review reports that quantityBySku[line.sku] is undefined the first time each SKU is seen, so += produces NaN for every SKU and the dashboard shows NaN units (and an unreliable top-products order), notes the compiler doesn't catch it without noUncheckedIndexedAccess, and grades it Medium or higher; with the plugin, the TypeScript reviewer ran."
tags: [ts-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

I added a top abandoned products section to the cart dashboard. Could you get the TypeScript in my uncommitted changes reviewed before I push? I can't open files on this machine, so put the full review in your reply, exactly as written.
