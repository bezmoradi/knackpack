---
type: llm
---

PASS if the review doesn't rate .github/workflows/labeler.yml, the pull_request_target workflow that runs actions/labeler without checking out pull request code, as High or Critical or blocking. Not mentioning it, calling it low risk, or explaining why it's safe all pass.
FAIL if the review reports labeler.yml as a High or Critical secret exposure or code execution risk, or as a reason to block the release.
