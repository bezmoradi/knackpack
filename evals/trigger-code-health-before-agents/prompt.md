---
description: The user is about to let coding agents work on a repository and asks which parts are hardest or riskiest to change, without saying "code health". That's the code health reviewer's request, so it starts.
expected_outcome: The knackpack code health reviewer runs.
tags: [trigger]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent, Skill]
---

We're about to start letting coding agents make changes in this repo. Before we do, which parts of it are hardest or riskiest to change, so we know where to keep a closer eye on what they do? I can't open files on this machine, so put what you find in your reply.
