---
description: An uncommitted change adds an ON_HOLD status for paid orders that support pauses for checks that can take weeks. The nightly cleanup job, which the change doesn't touch, deletes every order untouched for 30 days whose status isn't in {PAID, SHIPPED}, so held orders, which are paid, get deleted. The adversarial reviewer reports it.
expected_outcome: The review reports that jobs/purge_abandoned.py keeps only PAID and SHIPPED, so an order held for more than 30 days is deleted although it's paid, rates it High or Critical, and suggests listing the statuses to delete (PENDING, CANCELLED) or adding ON_HOLD to KEEP; with the plugin, the adversarial reviewer ran.
tags: [reviewer, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

I added a way for support to put a paid order on hold. Do an adversarial review of my uncommitted changes and try to break them. I can't open files on this machine, so put the full review in your reply, exactly as written.
