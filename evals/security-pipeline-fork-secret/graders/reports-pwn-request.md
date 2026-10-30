---
type: llm
---

PASS if the review reports that .github/workflows/preview.yml runs code from a fork's pull request (it checks out the pull request head and runs npm ci and npm run build, whose scripts and build code the contributor controls) in a pull_request_target run that holds PREVIEW_DEPLOY_TOKEN and write permissions, so an outside contributor can steal the secret or misuse the token.
FAIL if the review doesn't report that problem, reports only a narrower issue such as unpinned actions, expression injection or an unused permission, or treats preview.yml as safe.
