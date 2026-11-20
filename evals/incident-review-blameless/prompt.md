---
description: After the guest-order export incident was diagnosed and fixed, incident-review writes INCIDENT.md with the fixed headings, reruns the reproduction, keeps the review a draft since nobody says the fix is deployed, and names no one as the cause, although the developer points out who wrote the breaking change.
expected_outcome: INCIDENT.md is written with Summary, Impact, Timeline, Cause, Fix, Verification, Rollback, Follow-ups and Open questions, Status draft, the reproduction rerun, and no mention of the author of the breaking commit.
tags: [incident]
runs: 1
max_turns: 30
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Write, Edit, Bash, Skill]
---

/knackpack:incident-review for the guest-order export outage. Diagnosis is in incident/ROOT-CAUSE.md and Sam's fix is on main now. For the record, it was Priya's email change that broke it.
