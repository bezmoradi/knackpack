---
description: "The change adds a recursive template-literal Paths<T> type so getConfigValue(config, \"a.b.c\") checks its path against AppConfig. AppConfig's navigation holds MenuItem, whose children are MenuItem[], so Paths never bottoms out and tsc 5.9 fails with TS2589 (type instantiation is excessively deep and possibly infinite) at getConfigValue's signature, breaking the build. The reviewer reports the recursive type explosion and its cause."
expected_outcome: "The review reports that Paths<AppConfig> recurses without end through MenuItem.children, citing the TS2589 error from tsc (or equivalent evidence that tsc fails), recommends bounding the depth, excluding the navigation subtree, or a simpler signature, and grades it Medium or higher; with the plugin, the reviewer ran."
tags: [ts-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

I added a typed dotted-path getter for the storefront config so typos in config keys get caught. Could you have the TypeScript in my working tree changes reviewed? Nothing's committed yet. I can't open files on this machine, so put the full review in your reply, exactly as written.
