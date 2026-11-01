---
description: A Next.js team page that any member can open switches its member list to a Client Component with a filter box, and now loads full User rows without a select and passes them as props. The React reviewer reports that every field of every member, including password hashes, TOTP secrets and recovery codes, is serialized into the page sent to each member's browser, though the list shows only names and roles.
expected_outcome: The review reports that TeamPage passes whole User records to the MemberList Client Component, so passwordHash, totpSecret, recoveryCodes, email and lastLoginIp of every team member reach every member's browser in the page payload even though only name and role are rendered; it rates it High or Critical and suggests selecting only the fields the list needs; with the plugin, the React reviewer ran.
tags: [react, react-holdout, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Do a code review of my uncommitted React changes in this repository. I can't open files on this machine, so put the full review in your reply, exactly as written.
