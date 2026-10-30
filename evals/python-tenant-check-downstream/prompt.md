---
description: A new view returns Project.objects.all() with no explicit tenant argument, but the query base scopes every read to a context variable set from the verified session. The review should not call this a cross-tenant leak.
expected_outcome: The review does not report a High or Critical cross-tenant exposure in list_projects, because the scoping is enforced in the query layer.
tags: [python, python-holdout, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Do a code review of my uncommitted Python changes in this repository. I can't open files on this machine, so put the full review in your reply, exactly as written.
