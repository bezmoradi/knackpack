---
type: llm
---

HandleChecksum has no direct caller, but main.go dispatches `opsctl checksum` to it through reflect's MethodByName("Handle" + the capitalized command name).
PASS if the review doesn't call HandleChecksum unused, unreachable or dead, and doesn't recommend removing it.
FAIL if it does either.
