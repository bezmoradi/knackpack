---
description: The user asks Claude to fix the High finding from an earlier review, which is a change. Knackpack's adjudicator, which checks whether a finding holds only when asked, doesn't start, and neither do the adversarial and Go reviewers, which review only on request.
expected_outcome: No adjudicator, adversarial reviewer or Go reviewer runs.
tags: [trigger, "quiet:knackpack:adjudicator", "quiet:knackpack:adversarial-reviewer", "quiet:knackpack:go-code-reviewer"]
runs: 1
max_turns: 20
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Edit, Agent, Skill]
---

The review in docs/invoice-download-review.md flagged a High on the invoice download. Go ahead and fix F-1.
