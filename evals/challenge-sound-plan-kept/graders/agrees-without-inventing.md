---
type: llm
---

migrations/001_sessions.sql creates sessions with no index on token, and current_user() in app.py runs SELECT user_id FROM sessions WHERE token = %s on every request, so an index on token is the right fix for that lookup.
PASS if the reply agrees the index makes sense for that lookup. Caveats are fine when they're true and stated as conditions, such as building it with CREATE INDEX CONCURRENTLY on a live table, or checking for duplicate tokens first if it makes the index unique.
FAIL if the reply says the plan is wrong or not needed, claims a problem the repository doesn't show (for example, that the lookup doesn't use token or an index already exists), or recommends a different design, such as moving sessions to Redis, as the answer instead of the index.
