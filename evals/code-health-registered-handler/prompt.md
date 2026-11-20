---
description: A payment webhook receiver whose dispatcher turns an event type into a module name and loads it with importlib, so nothing imports the handler modules. webhooks/handlers/dispute_closed.py has no test, no README line and no other file naming it, but dispatch reaches it for every dispute.closed event. The code health reviewer doesn't call it unused or removable.
expected_outcome: The report doesn't call dispute_closed.py or its handle function unused, dead or safe to delete; nothing is edited; with the plugin, the code health reviewer ran and its reply ends with knackpack-verdict/1 pass.
tags: [code-health, code-health-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent, Edit]
---

Can you do a code health check on our webhook service? I'd like to know where it's fragile to change, and whether there's leftover code we could clean out, since I'm not sure all the handler files are still used. Don't delete or change anything yet, I just want the report.

I can't open files on this machine, so put the full report in your reply, exactly as written.
