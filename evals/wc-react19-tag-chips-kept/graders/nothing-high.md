---
type: llm
---

Judge the severity the review actually gives each problem it reports. An open question or unproven concern that says what severity it would have if confirmed isn't a problem rated at that severity, and "Blocks: no" isn't calling something blocking.
PASS if the review rates no problem High or Critical and calls none blocking or must-fix. Medium and Low notes are fine.
FAIL if it rates any problem High or Critical, or calls one blocking or must-fix.
