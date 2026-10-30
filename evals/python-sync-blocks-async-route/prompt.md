---
description: An uncommitted FastAPI async def endpoint, export_report, calls a new blocking helper that uses requests with a 30-second timeout and time.sleep backoff, while the existing plain def get_report endpoint calls a blocking helper from FastAPI's threadpool. The Python reviewer reports that export_report blocks the event loop and doesn't report get_report.
expected_outcome: The review reports that export_report runs the blocking fetch_export on the event loop, stalling every other request, and doesn't report the plain def get_report as blocking it; with the plugin, the Python reviewer ran.
tags: [python, python-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Do a code review of my uncommitted Python changes in this repository. I can't open files on this machine, so put the full review in your reply, exactly as written.
