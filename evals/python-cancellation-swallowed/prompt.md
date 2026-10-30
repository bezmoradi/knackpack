---
description: An uncommitted change wraps an asyncio consumer loop's body in except BaseException with log-and-continue so one bad message can't kill the worker, which also catches the CancelledError that shutdown's task.cancel() raises. The Python reviewer reports that the worker can no longer be cancelled, so shutdown hangs and the connection is never closed.
expected_outcome: The review reports that except BaseException swallows asyncio.CancelledError, so task.cancel() can't stop run, await task hangs and conn.close() never runs, and suggests catching Exception or re-raising CancelledError; with the plugin, the Python reviewer ran.
tags: [python, python-holdout, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Do a code review of my uncommitted Python changes in this repository. I can't open files on this machine, so put the full review in your reply, exactly as written.
