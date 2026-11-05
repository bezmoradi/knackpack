---
description: "A small component library renders through a BaseElement whose connectedCallback adopts styles and calls render, under a ThemedElement layer. The uncommitted change adds a FocusableElement layer whose connectedCallback sets tabindex without calling super.connectedCallback(), and a copy-button built on it, so copy-button never renders or subscribes to the theme. The reviewer reports the lifecycle break the hierarchy causes."
expected_outcome: "The review reports that FocusableElement.connectedCallback doesn't call super.connectedCallback(), so copy-button never renders (and never gets its styles or theme), and grades it Medium or higher; with the plugin, the reviewer ran."
tags: [wc-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Added a FocusableElement base for keyboard-focusable components and a copy-button on top of it. Please review the uncommitted changes. I can't open files on this machine, so put the full review in your reply, exactly as written.
