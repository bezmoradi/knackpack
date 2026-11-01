---
description: The user asks whether to move a Python app's sessions from Postgres to Redis, or try something simpler first, without saying "research". The question is an open decision between alternatives, so the Research skill starts. The app looks every session up by a token column that has no index and rewrites the session's last_seen on every request, so the simpler options are in the code.
expected_outcome: The Research skill loads. The reply's recommendation rests on how the app uses sessions, naming the missing index on the token column or the write on every request as something to fix or check before moving to Redis.
tags: [trigger]
runs: 1
max_turns: 30
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Skill]
---

Logins have been getting slow since we passed about 2,000 active users, and I think it's the sessions table in Postgres. Should we move sessions to Redis, or is there something simpler we should try first? Look at how the app uses sessions before you answer. I can't open files on this machine, so put everything in your reply.
