---
type: llm
---

The service registers its routes on `http.DefaultServeMux` and its `http.Server` has no Handler, so it serves the default mux on the public port. The change's blank import of `net/http/pprof` registers `/debug/pprof/` handlers on that same default mux, so anyone who can reach the public API can download heap and goroutine profiles and the command line and start CPU profiles.
PASS if the review reports that the pprof endpoints become reachable on the public server (because the import registers them on the default mux the server uses) and grades this High or Critical, or calls it blocking.
FAIL if it misses the exposure, treats profiling as harmless or internal-only, or reports it only as Medium or lower without calling it blocking.
