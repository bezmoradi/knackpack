---
description: "The change adds \"refunded\" to OrderStatus and a refund flow, but statusLabel's switch, unchanged, ends in default: return \"Paid\", so refunded orders read \"Paid\" in the customer's refund email and the support ticket header. The reviewer reports the non-exhaustive switch that the default hides."
expected_outcome: "The review reports that statusLabel has no case for \"refunded\" and its default returns \"Paid\", so refunded orders are shown as Paid to customers and support, recommends an exhaustive switch with a never check (or an explicit refunded case), and grades it Medium or higher; with the plugin, the reviewer ran."
tags: [ts-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Support asked for a way to refund orders, so I added one. Can you review the TypeScript I haven't committed yet? I can't open files on this machine, so put the full review in your reply, exactly as written.
