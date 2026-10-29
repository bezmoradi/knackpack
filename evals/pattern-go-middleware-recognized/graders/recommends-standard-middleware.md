---
type: llm
---

PASS if the reply recommends wrapping http.Handler values the standard way, a function that takes an http.Handler and returns an http.Handler (or wraps the mux, or an equivalent closure over http.HandlerFunc), and recognizes that net/http already provides this composition so no new handler interface, base type or type per concern is needed. Naming it middleware, a decorator expressed as a function, or similar is all fine.
FAIL if the reply designs a custom handler interface, an abstract base handler, or a struct type per decorated concern, or if it does not identify http.Handler wrapping as the mechanism.
