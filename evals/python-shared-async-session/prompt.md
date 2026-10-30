---
description: A new dashboard loader runs three repository calls concurrently with asyncio.gather over one shared AsyncSession. The review should report that SQLAlchemy forbids concurrent use of a single AsyncSession.
expected_outcome: The review reports that load_dashboard drives one AsyncSession from concurrent gather tasks, which SQLAlchemy does not support, and suggests a session per task or sequential awaits.
tags: [python, python-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Do a code review of my uncommitted Python changes in this repository. I can't open files on this machine, so put the full review in your reply, exactly as written.
