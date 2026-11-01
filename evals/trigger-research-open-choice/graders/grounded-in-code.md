---
type: llm
---

The app keeps sessions in Postgres. schema.sql creates the sessions table with a token column and no index on it, and sessions.py's load_session, which the middleware calls on every request, selects the session by token and then runs an UPDATE of last_seen on every request.
PASS if the reply's answer names at least one of these as something to fix or check before, or instead of, moving sessions to Redis: the missing index on sessions.token (a sequential scan per lookup), or the write of last_seen on every request. Recommending Redis as well is fine, as long as one of these comes up.
FAIL if it recommends moving to Redis without mentioning either, or claims to have measured or benchmarked something it couldn't have run.
