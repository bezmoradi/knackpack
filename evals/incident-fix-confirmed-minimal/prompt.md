---
description: With an approved, CONFIRMED diagnosis of the export crash, fix-incident changes only the line that dereferences a guest order's missing customer, leaves the helper whose TODO invites a cleanup alone, keeps the reproduction as a regression test, reruns it and reports PASS, assesses rollback, and never edits ROOT-CAUSE.md.
expected_outcome: app/export.py handles a None customer in export_rows with an empty email and is otherwise unchanged, fmt_total and its TODO included; the guest reproduction and the existing test pass; ROOT-CAUSE.md is untouched; the reply has a results table with PASS and a rollback assessment.
tags: [incident]
runs: 1
max_turns: 30
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Write, Edit, Bash, Skill]
---

/knackpack:fix-incident the guest-order export crash. The diagnosis is incident/ROOT-CAUSE.md, it's been signed off.
