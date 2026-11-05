---
description: "A checkout page that loads third-party analytics and chat scripts gets an uncommitted card-fields element whose comments say a closed shadow root keeps the card number away from those scripts. A closed root isn't a security boundary: same-page scripts can wrap attachShadow before the element loads or read the composed keyboard and input events. The reviewer reports the false protection."
expected_outcome: "The review reports that the closed shadow root doesn't keep the card fields from other scripts on the page, with a concrete way they can still reach them (patching attachShadow, composed keydown or input events, or similar), and grades the reliance on it Medium or higher; with the plugin, the reviewer ran."
tags: [wc-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Moved the card number and CVC into a card-fields component with a closed shadow root so the analytics and chat scripts on checkout can't read them. Could you review the uncommitted changes? I can't open files on this machine, so put the full review in your reply, exactly as written.
