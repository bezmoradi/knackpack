---
type: llm
---

main.go creates a context with context.WithTimeout from the flag, passes it to the request with http.NewRequestWithContext, and copies resp.Body to stdout under the same context, so the deadline covers connecting, the headers and reading the body.
PASS if the reply says the timeout also covers downloading the body, so a slow download is cut off when it expires, and bases that on the context passed to the request.
FAIL if it says the body download isn't covered, or answers without looking at how main.go uses the timeout.
