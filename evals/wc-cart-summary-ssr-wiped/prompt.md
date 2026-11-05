---
description: "The server renders cart-summary with a declarative shadow root holding the item count, total and checkout link. The uncommitted client definition calls attachShadow unconditionally and then fetches the cart before rendering, and attachShadow on a host with a declarative root empties it, so the server-rendered summary disappears on upgrade and stays blank if the fetch fails. The reviewer reports the hydration defect."
expected_outcome: "The review reports that attachShadow on a host that already has a declarative shadow root clears the server-rendered content, so the summary and checkout link vanish until the fetch completes (or for good if it fails), and grades it Medium or higher; with the plugin, the reviewer ran."
tags: [wc-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

The server already renders the cart summary with declarative shadow DOM; I added the client-side component so it refreshes the cart. Could you review my uncommitted changes? I can't open files on this machine, so put the full review in your reply, exactly as written.
