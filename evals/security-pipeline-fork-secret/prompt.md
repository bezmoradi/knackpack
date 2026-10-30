---
description: The security reviewer finds that a new pull_request_target workflow builds a fork's pull request with a deploy secret and write permissions in reach, grades it High or Critical, and blocks the release.
expected_outcome: The review reports that preview.yml runs the pull request's own npm ci and npm run build where PREVIEW_DEPLOY_TOKEN and write permissions are available, rates it High or Critical, and recommends BLOCKED.
tags: [security, security-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Do a security review of my uncommitted changes in this repository and give me your release recommendation. I can't open files on this machine, so put the full review in your reply, exactly as written.
