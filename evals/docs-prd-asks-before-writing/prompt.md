---
description: The user asks for a PRD for adding SSO to a small invoicing app, and neither the request nor the repository says what problem SSO solves, who is asking for it, or how success would be judged. With Write docs, Claude should ask for those facts, in a few questions, before writing anything, rather than write a PRD of guesses.
expected_outcome: No PRD file is written, and the reply asks, in a few questions, what problem SSO is meant to solve or who wants it, and how success will be judged.
tags: [write-docs, docs-dev]
runs: 1
max_turns: 20
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Write, Skill]
---

Can you write a PRD for adding SSO to our app? Put it under docs/.
