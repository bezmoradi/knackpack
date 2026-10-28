---
type: llm
---

PASS if the review reports that make_thumbnail lets a crafted file name run shell commands, because it passes the name to a shell (shell=True) inside the command string.
FAIL if the review doesn't report that problem, or doesn't treat it as a security issue.
