---
description: Sales and customer success notes give the problem, who has it and the outcome for SSO in a small invoicing app, but also state success as "SSO live by end of November" and add a rebranded login page and per-customer login themes that no stated outcome needs. With Write docs, Claude writes the PRD without asking again, ties its requirements and success measure to the outcome (people disabled in the identity provider can no longer get in, and the blocked renewals close), keeps the two extra asks out of the requirements, and says in one line what the PRD leaves out.
expected_outcome: docs/prd-sso.md exists; its success measure is the outcome rather than the ship date, its requirements serve that outcome, and the login page refresh and per-customer themes are not requirements; the reply names what the PRD leaves out.
tags: [write-docs, docs-dev]
runs: 1
max_turns: 20
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Write, Skill]
---

Sales and CS pulled together notes/sso-request.md. Write the PRD for SSO from it and save it as docs/prd-sso.md.
