---
description: The user asks for rate limiting on a Python login endpoint, a change to make rather than a review. Neither knackpack's security reviewer nor its Python reviewer starts, since both run only when the user asks for a review.
expected_outcome: Neither the security reviewer nor the Python reviewer runs.
tags: [trigger, "quiet:knackpack:security-reviewer", "quiet:knackpack:python-code-reviewer"]
runs: 1
max_turns: 20
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Edit, Agent, Skill]
---

Add rate limiting to POST /login in app/auth.py: five failed tries per account in 15 minutes, then answer 429 until the window passes. Keep it in memory for now, we run a single instance.
