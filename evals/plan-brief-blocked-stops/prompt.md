---
description: Plan implementation is given a requirements brief in the knackpack-requirements/1 format whose question Q-02, whether a shift swap takes effect when the teammate accepts or only once a manager approves it, says Blocking yes. It runs requirements-check.sh, which prints "blocked Q-02", and stops before planning, naming Q-02 and what it asks, instead of choosing an answer and planning around it.
expected_outcome: requirements-check.sh ran on the brief; no PLAN file is written and no file is edited; the reply names Q-02, says what it asks, gives no work packages, and asks the user to answer it or say to plan around it.
tags: [plan-brief]
runs: 1
max_turns: 25
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Write, Edit, Bash, Skill]
---

/knackpack:plan-implementation Plan from the brief at docs/REQUIREMENTS.md. We'd like to get shift swaps into this sprint, so a plan today would be great.
