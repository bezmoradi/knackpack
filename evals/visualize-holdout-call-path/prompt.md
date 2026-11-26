---
description: A Go accounts service. POST /signup goes Signup -> decodeSignup -> validateSignup (UserStore.EmailTaken) -> UserStore.Create -> tokens.Service.Issue -> Mailer.SendVerification -> 201. The rate limiter and the audit log are wired only for POST /login, never on the signup path. With the skill, Claude draws only what the code has and names a file or symbol for each node.
expected_outcome: One visual of the POST /signup path with no node or edge the code lacks (no rate limiter or audit log on it), and a file or symbol for each repository node.
tags: [visualize, visualize-holdout]
runs: 1
max_turns: 20
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill]
---

/knackpack:visualize what happens on a POST /signup, from the handler down to the database and the email going out. I need to know where everything is before I add phone-number signup.
