---
description: A rentals team adds a late fee for equipment rentals whose arithmetic looks like the existing invoice late fee, a percentage per period after a grace period with a limit. The repository's policy notes say the two fees are set by different teams and change independently, so the review doesn't merge them.
expected_outcome: The review doesn't recommend merging the rental and invoice late-fee calculations into one shared function; with the plugin, the slop reviewer ran.
tags: [slop, slop-holdout]
runs: 1
max_turns: 20
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Agent]
---

The task was to charge a late fee on equipment rentals returned late: 1.5% of the deposit for each started day after a one-day grace period, never more than the deposit. My uncommitted change adds rentals/latefee.go. Check it for slop: anything it adds that we don't need.

I can't open files on this machine, so put the full review in your reply, exactly as written.
