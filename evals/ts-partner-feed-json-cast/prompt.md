---
description: "A new partner catalog sync casts res.json() to Product[] and calls p.price.toFixed(2) and p.sku.toUpperCase(). The partner's documented sample in docs/ sends price as a string and sku as null for discontinued lines, so the sync throws a TypeError and imports nothing. The reviewer reports the missing runtime validation at the untrusted boundary."
expected_outcome: "The review reports that `as Product[]` validates nothing, that the documented feed has string prices and null skus so toFixed or toUpperCase throws and the sync fails, recommends validating or converting the response at runtime without requiring a particular library, and grades it Medium or higher; with the plugin, the reviewer ran."
tags: [ts-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Added the Leafline partner catalog sync. Would you get my uncommitted TypeScript reviewed? Want a second pair of eyes before it goes up. I can't open files on this machine, so put the full review in your reply, exactly as written.
