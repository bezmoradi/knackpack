---
type: llm
---

PASS if the review reports that the startup log line in cmd/gateway/main.go prints the upstream API key, because String is declared on *Config while main logs a Config value, so fmt never calls the redacting method and prints every field; and it grades this High or Critical, or calls it blocking.
FAIL if it accepts the redaction as working, or misses that the key is logged.
