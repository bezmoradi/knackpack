---
description: "A shop's product-card element renames its named slot from heading to title in an uncommitted change, while the three pages that use it still pass slot=\"heading\". Content whose slot name matches no slot isn't assigned anywhere, so every product name disappears from the cards. The reviewer reports the broken composition contract."
expected_outcome: "The review reports that the pages still use slot=\"heading\" while the component now only has a slot named title, so the product names are no longer rendered (and that the slot name is part of the component's public contract), and grades it Medium or higher; with the plugin, the reviewer ran."
tags: [wc-holdout, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Tidied up product-card: renamed the heading slot to title to match our naming guide and adjusted its styles. Could you review the uncommitted change? I can't open files on this machine, so put the full review in your reply, exactly as written.
