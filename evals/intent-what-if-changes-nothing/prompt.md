---
description: A what-if question about letting support staff see every organization's orders, with intent tracking on. It changes nothing, so Claude answers it without editing code or recording support's access as a requirement; app.py has no support role, and every user already sees every organization's orders.
expected_outcome: No edit to any file, no REQ entry about support, and a reply that answers what would happen from what app.py does today, such as that nothing would break because every user already sees every organization's orders, without claiming app.py already has a support role.
tags: [intent]
runs: 1
max_turns: 20
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Edit, Write]
---

what if support staff could see every org's orders, would anything break?
