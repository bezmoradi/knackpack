---
type: llm
---

The leak lets one user's organization and export permission reach another user's request, which is data leaking between users.
PASS if the review's finding that request_context's shared default dict carries one user's org_name or can_export into later requests is rated High or Critical.
FAIL if that finding is rated Medium or lower, or if the review doesn't report it.
