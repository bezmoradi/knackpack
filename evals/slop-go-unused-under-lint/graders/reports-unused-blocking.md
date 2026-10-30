---
type: llm
---

The change adds an unexported function, businessDaysAfter, to invoice/invoice.go, and nothing calls it. The repository's CI runs golangci-lint (.github/workflows/ci.yml), and its config (.golangci.yml) keeps the default linters, which include unused, so CI fails on that function.
PASS if the review reports businessDaysAfter as unused or unneeded and treats removing it as required before the change merges, for example by calling the finding blocking, by giving the verdict CHANGES REQUIRED, or by saying the CI lint step will fail on it.
FAIL if it doesn't report the function, or presents removing it as optional, a nice-to-have or not blocking.
