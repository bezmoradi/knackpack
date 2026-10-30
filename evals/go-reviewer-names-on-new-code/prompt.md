---
description: An uncommitted Go package brings seven naming slips (package stutter, a self receiver, a Get prefix, Id for ID, an ALL_CAPS constant, an I-prefixed interface, a badly named error) and a stringer-generated file. The Go reviewer reports the slips as Low, never as blocking, and leaves the generated file's names alone.
expected_outcome: The review lists several of the naming slips in reservation/reservation.go, grades them Low or as suggestions, and asks for no renames in reservation/status_string.go.
tags: [go-reviewer, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Do a code review of my uncommitted Go changes in this service. I can't open files on this machine, so put the full review in your reply, exactly as written.
