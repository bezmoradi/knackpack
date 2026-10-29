---
type: llm
focus: { source: file, path: main.go }
---

PASS if main.go still has the same straightforward shape: a flag is parsed, files are counted in a loop, and the verbose behavior is a plain conditional print. Small refactors, such as passing the flag's value into countLines, are fine.
FAIL if the file introduces an interface, a type hierarchy, an options struct or builder, a plug-in registry, or any other abstraction for the verbose behavior.
