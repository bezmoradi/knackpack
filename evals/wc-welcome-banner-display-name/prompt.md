---
description: "A dashboard shows a welcome-banner element with the signed-in user's display name, which users set themselves. The uncommitted element writes the name attribute into its shadow root with innerHTML, so a display name containing markup runs script in every session that renders it, shadow root or not. The reviewer reports the DOM XSS."
expected_outcome: "The review reports that the user-controlled display name reaches innerHTML in the shadow root, so markup such as an img with onerror runs script (shadow DOM is no protection), names the source, and grades it High or Critical; with the plugin, the reviewer ran."
tags: [wc-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Small one: a welcome banner component for the dashboard. Can you review my uncommitted changes? I can't open files on this machine, so put the full review in your reply, exactly as written.
