---
description: The same Next.js app adds a deleteProject Server Action that checks the session, validates the id and deletes with deleteMany scoped to the signed-in owner, failing when nothing matched, as renameProject does. The React reviewer doesn't report missing authentication or authorization and finds nothing High or Critical.
expected_outcome: The review doesn't claim deleteProject lacks an authentication or ownership check and raises nothing High, Critical or blocking; with the plugin, the React reviewer ran.
tags: [react, react-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

I added deleting a project to our Next.js app. Can you review it before I commit? It's all uncommitted. I can't open files on this machine, so put the full review in your reply, exactly as written.
