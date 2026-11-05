---
description: "An admin app swaps views with replaceChildren, and each view contains a command-palette element. The uncommitted palette adds a keydown listener to document in connectedCallback and never removes it, so every navigation leaves a detached palette that still handles Ctrl+K, fetches the command list and stays in memory. The reviewer reports the missing cleanup."
expected_outcome: "The review reports that the document keydown listener added in connectedCallback is never removed on disconnect, so palettes from earlier views keep responding (one extra fetch per navigation) and are kept in memory, and grades it Medium or higher; with the plugin, the reviewer ran."
tags: [wc-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Added a Ctrl+K command palette to every admin view. Please review my uncommitted changes. I can't open files on this machine, so put the full review in your reply, exactly as written.
