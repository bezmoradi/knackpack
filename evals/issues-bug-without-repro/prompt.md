---
description: The user asks for a bug report about invoice PDFs that sometimes show the wrong currency, which the team can't reproduce yet, and guesses at the exchange-rate cache. The create-issues skill's draft says the reproduction is unknown and treats the cache as a hypothesis, not the cause.
expected_outcome: The draft says the reproduction steps are unknown and invents none, presents the exchange-rate cache as a suspected cause to investigate, and doesn't make fixing the cache the acceptance criterion.
tags: [create-issues, issues-dev]
runs: 1
max_turns: 20
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Skill, Write]
---

Draft a bug report: some customers say their invoice PDFs sometimes show the wrong currency. We can't reproduce it yet. Maybe it's the exchange-rate cache. I can't open files on this machine, so put everything in your reply.
