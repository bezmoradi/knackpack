---
type: llm
---

The change adds `omitempty` to `email_enabled` (a bool), so the response leaves the field out whenever a user has email turned off. The web client (web/prefs.js) reads a missing `email_enabled` as `true`, and its save sends the whole object back with PUT, which replaces the stored preferences. So a user who turned email off sees it as on, and saving any other setting switches email back on.
PASS if the review reports that `omitempty` on `email_enabled` drops `false` and the client then treats email as enabled (shows it as on, or writes `true` back on the next save), and grades this High or Critical, or Medium and blocking, or otherwise calls it blocking or must-fix.
FAIL if it misses this, calls the omitempty change safe, or reports it only as a non-blocking Medium or lower.
