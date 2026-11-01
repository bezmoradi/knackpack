---
description: A CLI's changelog has a released 1.4.0 entry, tagged v1.4.0. Since then the branch added CSV export, fixed a header-order bug that the CSV commit itself introduced, and renamed export --out to --output while keeping --out as an alias. With Write docs, Claude adds an entry for the next release that lists CSV export and the rename, with --out still working, and no fix for the header bug, which users of 1.4.0 never had, and leaves the 1.4.0 entry as it shipped.
expected_outcome: CHANGELOG.md gains a new entry (Unreleased or a next version) listing CSV export and the --output rename with --out kept as an alias, without listing the CSV header-order fix as a user-facing fix, and the 1.4.0 entry is unchanged.
tags: [write-docs, docs-dev]
runs: 1
max_turns: 20
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Edit, Write, Bash, Skill]
---

Can you update CHANGELOG.md with what's changed on this branch since the last release? We're cutting the next one this week.
