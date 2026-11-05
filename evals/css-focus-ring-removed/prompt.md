---
description: "An uncommitted change removes the focus outline from buttons, links and inputs to stop the ring appearing on mouse clicks, with no :focus-visible replacement, so keyboard users can't see focus. The CSS reviewer reports the WCAG 2.4.7 failure as High or blocking."
expected_outcome: "The review says outline: none on :focus leaves no visible focus indicator for keyboard users (2.4.7, AA), suggests :focus-visible, and grades it High or blocking."
tags: [css-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Designers kept complaining about the blue rings when you click buttons, so I turned them off. Review my CSS change please. I can't open files on this machine, so put the full review in your reply, exactly as written.
