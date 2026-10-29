---
type: llm
---

PASS if the reply reports as a defect at least one of these two contract breaks in cache/fetcher.go: Rate returns a nil error (and a zero or stale rate) when the wrapped fetch fails, so callers quote a rate they didn't get, which the Fetcher contract forbids; or Rate calls the wrapped Fetcher with context.Background(), so the caller's two-second timeout no longer applies to the network call.
FAIL if the reply reports neither, or presents them as accepted because the code comment says so.
