---
description: An ops CLI dispatches each command to an exported method named Handle<Command>, found with reflect's MethodByName. The change adds HandleChecksum, which nothing calls directly but the dispatcher reaches, and handleChecksumDir, an unexported method no task asked for that MethodByName can never find. The review reports the second and keeps the first.
expected_outcome: handleChecksumDir is reported as unused or unreachable; HandleChecksum isn't called unused and isn't recommended for removal; with the plugin, the slop reviewer ran.
tags: [slop, slop-dev]
runs: 1
max_turns: 20
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Agent]
---

The task was to add an `opsctl checksum` command that prints the SHA-256 of the files it's given. My uncommitted change is in commands.go and README.md. Check it for slop: anything it adds that we don't need.

I can't open files on this machine, so put the full review in your reply, exactly as written.
