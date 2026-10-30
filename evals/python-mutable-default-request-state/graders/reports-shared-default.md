---
type: llm
---

request_context in app/context.py has the default overrides={}, writes into it with setdefault and returns it, and profile_response and export_response in app/handlers.py call it without overrides.
PASS if the review reports that request_context's default dict is created once and shared across calls, so the org_name and can_export set for one user's request carry into later requests for other users (for example a viewer getting an earlier admin's can_export, or the wrong organisation's name).
FAIL if the review doesn't report that problem, or mentions the mutable default only as a style or lint issue without saying that values leak from one request to the next.
