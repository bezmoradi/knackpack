---
description: "A help page gets an uncommitted info-disclosure element whose open property reads hasAttribute('open') but whose setter writes setAttribute('open', value), so setting it to false leaves open="false" on the element, which still counts as open. The close button can never close it. The reviewer reports the boolean reflection defect."
expected_outcome: "The review reports that the open setter writes the string false into the attribute instead of removing it, so the presence-based getter and :host([open]) styles still treat it as open and the close button doesn't close it, and grades it Medium or higher; with the plugin, the reviewer ran."
tags: [wc-holdout, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Wrote an info-disclosure component for the help center FAQ. Can you review my uncommitted changes? I can't open files on this machine, so put the full review in your reply, exactly as written.
