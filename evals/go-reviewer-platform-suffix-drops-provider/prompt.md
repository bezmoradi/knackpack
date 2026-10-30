---
description: An uncommitted push_android.go registers an Android push provider in init, but its _android suffix restricts it to GOOS=android, so the Linux image the Dockerfile builds never registers the provider. The Go reviewer reports the dropped file as High or Critical.
expected_outcome: The review says push_android.go builds only for Android because of its file name, so the android-push provider is missing from the Linux build, and grades it High or Critical in the findings table.
tags: [go-reviewer, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Do a code review of my uncommitted Go changes in this service. I can't open files on this machine, so put the full review in your reply, exactly as written.
