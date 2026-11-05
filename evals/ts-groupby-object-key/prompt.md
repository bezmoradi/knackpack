---
description: "A new overdue-reminder job calls the shared groupBy(items, key) with key \"customer\", whose value is an object. groupBy's K extends keyof T accepts it and buckets by String(item[key]), so every invoice lands in one \"[object Object]\" bucket and one customer is emailed every customer's overdue invoices. The reviewer reports the grouping failure and the helper's too-loose contract."
expected_outcome: "The review reports that grouping by the customer object makes every overdue invoice share the \"[object Object]\" key, so one reminder goes to the first customer listing all customers' invoices and the others get none, names groupBy's K extends keyof T constraint (or its String() key) as letting this type-check, recommends grouping by customer.id through a key function or a constraint to string or number values, and grades it Medium or higher; with the plugin, the reviewer ran."
tags: [ts-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

New job that emails each customer a reminder about their overdue invoices. Would you get the uncommitted TypeScript reviewed for me? I can't open files on this machine, so put the full review in your reply, exactly as written.
