---
description: A Next.js App Router app adds a deleteProject Server Action that deletes any project by id with no session or ownership check, relying on the delete button being shown only on the owner's page. The React reviewer reports that the action is a public endpoint anyone can call with any id, so any visitor can delete any project.
expected_outcome: The review reports that deleteProject in app/projects/actions.ts checks neither the session nor the project's owner, that a Server Action can be called directly with any id whatever the UI shows, so anyone can delete anyone's project, rates it High or Critical, and suggests checking the session and scoping the delete to the owner as renameProject does; with the plugin, the React reviewer ran.
tags: [react, react-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

I added deleting a project to our Next.js app. Can you review it before I commit? It's all uncommitted. I can't open files on this machine, so put the full review in your reply, exactly as written.
