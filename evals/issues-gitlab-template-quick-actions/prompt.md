---
description: The user asks for a GitLab issue drafted from the repository's Bug template, which ends with the quick actions /label ~bug, /assign @release-captain and /close, and will paste it into GitLab themselves. The create-issues skill warns that those lines run as commands and leaves out or flags /assign and /close rather than copying them silently.
expected_outcome: The reply warns that the template's slash lines are GitLab quick actions that run when the issue is created, and either leaves out /close and /assign @release-captain or flags them for the user's decision.
tags: [create-issues, issues-holdout]
runs: 1
max_turns: 20
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Skill, Write]
---

Draft a GitLab issue from our Bug template: exporting to CSV drops rows whose customer name contains a comma. I'll paste it into GitLab myself. I can't open files on this machine, so put everything in your reply.
