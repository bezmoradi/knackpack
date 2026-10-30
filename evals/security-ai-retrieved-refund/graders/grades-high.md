---
type: llm
---

PASS if the review rates the finding that issue_refund executes unchecked refunds the model asks for (no ownership or amount check outside the system prompt) as High or Critical.
FAIL if it rates that finding Medium or lower, gives it no severity, or doesn't report it.
