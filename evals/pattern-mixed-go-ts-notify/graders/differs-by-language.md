---
type: llm
---

PASS if the reply recommends a notification design for the Go side and a design for the TypeScript side separately, and the two differ where the languages differ: for example callbacks or a channel with stated goroutine ownership and context cancellation in Go, and EventTarget, an EventEmitter-style subscription, a store, or callbacks tied to an AbortSignal in TypeScript. It must name at least one semantic difference that drives the split, such as the concurrency model (goroutines versus a single-threaded event loop) or the cancellation mechanism (context versus AbortSignal), and it should treat the HTTP contract between the two as its own concern rather than a reason to copy one shape to the other.
FAIL if the reply prescribes one identical structure for both sides in the name of consistency without discussing the semantic differences, or gives a recommendation for only one side.
