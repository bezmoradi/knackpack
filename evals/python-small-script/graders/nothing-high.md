---
type: llm
---

Judge the severity the review actually gives each problem it reports, and its overall verdict. An open question or unproven concern that says what severity it would have if confirmed isn't a problem rated at that severity, and "Blocks: no" or "doesn't block" isn't calling something blocking.
PASS if no problem the review reports is rated High or Critical, and it calls none blocking or must-fix. Medium and Low findings, questions and suggestions are fine.
FAIL if it rates a reported problem High or Critical, or calls one blocking or must-fix.
