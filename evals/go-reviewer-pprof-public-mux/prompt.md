---
description: A public catalog API registers its routes on http.DefaultServeMux and serves it with a nil Handler; an uncommitted change adds a blank import of net/http/pprof to chase memory growth, which publishes /debug/pprof on the public listener. The Go reviewer reports the exposure as High or blocking.
expected_outcome: The review says the net/http/pprof import registers its handlers on the default mux that the public server serves, exposing profiles, heap dumps and the command line to anyone, and grades it High or Critical, or blocking.
tags: [go-reviewer, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

The catalog API's memory keeps growing in production and we need to see where it goes, so I hooked up profiling. Please review my uncommitted Go changes before I deploy them. I can't open files on this machine, so put the full review in your reply, exactly as written.
