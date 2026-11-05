---
description: "A project with semantic color tokens that switch for dark mode adds a promo card that takes its background from the surface token but hard-codes a dark gray text color, so in dark mode the text is dark gray on a near-black card. The CSS reviewer reports the hard-coded color that bypasses the tokens and the dark-mode contrast failure it causes."
expected_outcome: "The review says the card's hard-coded text color doesn't switch with the theme while its background token does, so in dark mode the text is nearly invisible, and grades it High or Medium and blocking."
tags: [css-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

New promo card for the home page. Can you review my CSS? I can't open files on this machine, so put the full review in your reply, exactly as written.
