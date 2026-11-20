---
description: A Python subscriptions API in which billing/api.py changed in 13 of 17 commits and update_subscription in 10. The other handlers check each field of the request body, but update_subscription casts json.loads(body) to the SubscriptionUpdate TypedDict and indexes it unchecked, so a missing plan or a string for seats raises mid-handler. The code health reviewer names that unchecked boundary at update_subscription.
expected_outcome: A finding names update_subscription in billing/api.py as using parsed JSON as the SubscriptionUpdate type without validating it; nothing is edited; with the plugin, the code health reviewer ran and its reply ends with knackpack-verdict/1 pass.
tags: [code-health, code-health-holdout, slow, "starts:knackpack:code-health-reviewer"]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent, Edit]
---

The billing API has grown fast this year and most of our changes land in the subscription code. Before we add usage-based pricing, could you run a code health check and tell me where it's riskiest to change and what's worth shoring up first? Please don't change anything.

I can't open files on this machine, so put the full report in your reply, exactly as written.
