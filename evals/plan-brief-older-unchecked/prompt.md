---
description: Plan implementation is given a requirements brief written before the knackpack-requirements/1 format, with no marker line and no Blocking markers. It runs requirements-check.sh, which prints "none", plans from the brief as before, and says the brief wasn't checked.
expected_outcome: requirements-check.sh ran on the brief; the plan is saved as a PLAN file and given in the reply with ordered work packages for REQ-01 to REQ-03; the reply says the brief wasn't checked because it predates the format; no file is edited.
tags: [plan-brief]
runs: 1
max_turns: 40
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Write, Edit, Bash, Skill]
---

/knackpack:plan-implementation Plan from the brief at docs/REQUIREMENTS.md. It's the weekly hours view the managers keep asking for, hopefully a fairly small one.
