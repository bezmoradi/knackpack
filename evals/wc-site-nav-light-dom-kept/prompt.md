---
description: "A marketing site whose README says its custom elements enhance server-rendered markup in the light DOM, so the global stylesheet and utility classes keep styling them, gets an uncommitted, correct site-nav element that wires a native button's aria-expanded to a list with an AbortController for cleanup. The reviewer doesn't demand shadow DOM and reports nothing serious."
expected_outcome: "The review rates no problem High or Critical and doesn't report the use of light DOM instead of shadow DOM as a defect at Medium or higher; with the plugin, the reviewer ran."
tags: [wc-holdout, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Added a site-nav element for the mobile menu on the marketing site. Please review my uncommitted changes. I can't open files on this machine, so put the full review in your reply, exactly as written.
