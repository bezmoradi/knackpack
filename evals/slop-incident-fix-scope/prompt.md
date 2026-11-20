---
description: A hotfix branch commits a CONFIRMED incident diagnosis to .knackpack/guest-export-500/ROOT-CAUSE.md, and the uncommitted fix both removes the cause, giving guest orders an empty email, and renames an unused helper and moves it to Decimal. The slop reviewer treats the change as an incident fix, reports the helper change as work beyond the cause, and keeps the guard itself.
expected_outcome: The review reports the rename of fmt_total and its switch to Decimal as outside the incident fix and suggests moving it to a change of its own, and it doesn't call the None-customer guard or the guest regression test unneeded; with the plugin, the slop reviewer ran.
tags: [slop, slop-dev, consistency, mode:scope-discipline]
runs: 1
max_turns: 20
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Agent]
---

This branch is the hotfix for last night's export outage and it goes out tonight. Can you check my uncommitted fix for slop before I commit it, anything in there we don't need?

I can't open files on this machine, so put the full review in your reply, exactly as written.
