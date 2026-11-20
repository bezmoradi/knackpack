---
description: A shipping-quote service with a year of history, in which every carrier rule lands in rates/quote.py's quote(), a 105-line function nested six deep that changes in 31 of the 35 commits, while the other modules are small and change a few times. The code health reviewer names quote.py as a hotspot, grades it Medium or Low, and says which stretch of history it measured.
expected_outcome: The report names rates/quote.py as a hotspot, where frequent change meets size or nesting; its findings table grades that finding Medium or Low and grades nothing on quote.py High or Critical; it states the history window it measured; nothing is edited; with the plugin, the code health reviewer ran and its reply ends with knackpack-verdict/1 pass.
tags: [code-health, code-health-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent, Edit]
---

We've got another round of carrier work coming up on this service and I'd like to know where it's going to hurt before we start. Can you do a code health check on the repo: which parts are hardest to change, and what's worth tidying first? Don't change anything yet.

I can't open files on this machine, so put the full report in your reply, exactly as written.
