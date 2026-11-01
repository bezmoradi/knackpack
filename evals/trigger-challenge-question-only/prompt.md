---
description: A question about what a Go CLI's -timeout flag covers asks for no change, so Challenge requirements doesn't start, and the answer comes from the code.
expected_outcome: The challenge-requirements skill never loads, nothing is edited, and the reply says the timeout covers the whole request, reading the body included.
tags: [trigger]
runs: 1
max_turns: 12
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Edit, Skill]
---

Quick question about fetch: does -timeout only cover connecting and getting the headers back, or does it also cover downloading the body? Someone on the team thinks a slow download can run forever.
