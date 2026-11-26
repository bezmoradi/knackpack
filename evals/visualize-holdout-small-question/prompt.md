---
description: 'The Go accounts service. tokens.Service.Issue (internal/tokens/tokens.go) has three direct callers: Handlers.Signup (internal/httpapi/signup.go:66), Handlers.ResendVerification (signup.go:90) and Handlers.RequestPasswordReset (internal/httpapi/reset.go:16). IssueAPIKey and tokens.Service.Verify have similar names and don''t call it. A small question, so with the skill Claude answers with one visual and only, and all of, the real callers.'
expected_outcome: At most one fenced block in the reply; every function shown calling Issue really calls it, and all three are shown.
tags: [visualize, visualize-holdout]
runs: 1
max_turns: 15
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill]
---

/knackpack:visualize quick picture of what calls tokens.Issue, I'm about to add an expiry argument to it
