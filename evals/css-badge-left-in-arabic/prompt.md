---
description: "A messaging app that ships Arabic and Hebrew sets dir from the locale; an uncommitted change positions an unread badge and icon spacing with left, margin-right and text-align: left, which land on the wrong side in right-to-left layouts. The CSS reviewer reports the RTL breakage."
expected_outcome: "The review says the physical properties (left, margin-right, text-align: left) don't flip under dir=rtl, so in the Arabic and Hebrew UI the badge and spacing land on the wrong side, recommends logical properties, and grades it Medium or higher."
tags: [css-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Can you review the CSS for the new unread badge on conversation rows? I can't open files on this machine, so put the full review in your reply, exactly as written.
