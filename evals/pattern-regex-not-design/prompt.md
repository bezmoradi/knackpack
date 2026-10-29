---
description: A request for a regex pattern that matches ISO dates is not a design question. No knackpack reviewer starts, and a regex is produced.
expected_outcome: A regular expression is given; no knackpack reviewer starts.
tags: [pattern, pattern-dev, quick]
max_turns: 20
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Agent]
---

Write a regex pattern that matches ISO 8601 calendar dates like 2026-10-29 but rejects 2026-13-40. Just the pattern and a one-line explanation.
