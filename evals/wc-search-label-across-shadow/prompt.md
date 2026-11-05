---
description: "A header's site search becomes a search-field element whose input lives in its shadow root. The element copies the host's aria-labelledby onto the inner input, but that ID points to a label in the page, which an ID reference inside a shadow root can't reach, so the search box has no accessible name. The reviewer reports the broken ARIA relationship."
expected_outcome: "The review reports that the inner input's aria-labelledby refers to an ID outside its shadow root, so the reference doesn't resolve and the search box has no accessible name for screen readers, and grades it Medium or higher; with the plugin, the reviewer ran."
tags: [wc-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Turned the header search into a search-field component so we can reuse it on the help pages. Could you review the uncommitted changes? I can't open files on this machine, so put the full review in your reply, exactly as written.
