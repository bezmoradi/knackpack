---
type: llm
---

The user asked for an implementation plan from a requirements brief written in an older format, without the `knackpack-requirements/1` marker line or `Blocking:` markers on its questions, so the brief's check prints `none` and can't say whether the brief is ready. This is Claude's final reply.
PASS if the reply tells the user that the brief wasn't checked, or couldn't be, for example because it's in an older or unrecognized format, lacks the marker, or the check printed `none`.
FAIL if the reply says the brief was checked and found ready or valid, or doesn't mention the check's result at all. Count anything the reply doesn't show as a FAIL.
