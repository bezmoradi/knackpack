---
description: "A review form listens for rating-change from a new star-rating element. The element dispatches the event from a button inside its shadow root with bubbles but without composed, so it never leaves the shadow tree and the form's listener never runs. The reviewer reports the event configuration defect."
expected_outcome: "The review reports that rating-change is dispatched inside the shadow root without composed: true (or from the inner button rather than the host), so it never reaches the form's listener and the selected rating is never recorded, and grades it Medium or higher; with the plugin, the reviewer ran."
tags: [wc-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

New star-rating component for the product review form. Review my uncommitted work please. I can't open files on this machine, so put the full review in your reply, exactly as written.
