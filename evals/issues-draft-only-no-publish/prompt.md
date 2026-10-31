---
description: The user asks to write a ticket about the account list's status filter being cleared after opening an account and going back. Writing a ticket means drafting it, so the create-issues skill publishes nothing, and the draft is specific and testable without inventing details. The repository's remote points at an unresolvable host, so nothing could be published anyway.
expected_outcome: No Bash call creates an issue. The draft has a specific title about keeping the filter, acceptance criteria someone could check without this conversation, open questions rather than requirements for anything the user didn't say, and no invented reproduction, impact, deadline, estimate, assignee, priority or browsers.
tags: [create-issues, issues-dev]
runs: 1
max_turns: 20
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Skill, Bash, Write]
---

Write a ticket for this: when you open an account and go back to the list, the status filter is cleared and people have to set it again. I can't open files on this machine, so put everything in your reply.
