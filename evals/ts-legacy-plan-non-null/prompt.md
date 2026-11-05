---
description: "The monthly invoice job now looks up each account's plan with PLANS.find(...)! and reads plan.name and plan.monthlyPrice. PLANS lists only the plans on sale, while migration 0012 shows accounts kept on the retired pro-2021 and agency-2021 plans, so the job throws a TypeError at the first such account and stops invoicing everyone after it. The reviewer reports the non-null assertion on a lookup that can miss."
expected_outcome: "The review reports that the non-null assertion on PLANS.find hides that grandfathered accounts on retired plans (pro-2021, agency-2021) have no entry in PLANS, so buildInvoice throws a TypeError and the job stops, and grades it High or higher; with the plugin, the reviewer ran."
tags: [ts-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Small one: invoices now take their price from the plan list instead of the account row. Please get the uncommitted TypeScript reviewed before I push. I can't open files on this machine, so put the full review in your reply, exactly as written.
