---
description: The user asks for a CSS fix, an account menu cut off at the edge of its card because the card clips its overflow. Changing a stylesheet starts the CSS engineering skill on its own; the CSS reviewer, which reviews CSS only when the user asks for a review, doesn't start.
expected_outcome: The css-engineering skill loads, and the knackpack CSS reviewer never runs.
tags: [trigger, "starts:knackpack:css-engineering", "quiet:knackpack:css-code-reviewer"]
runs: 1
max_turns: 20
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Edit, Agent, Skill]
---

The Account menu on the Billing card gets chopped off, only the first item shows and the rest just disappears at the bottom of the card. Can you fix it in styles/cards.css? I'd like to keep the rounded corners on the cards.
