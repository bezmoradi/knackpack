---
type: llm
---

PASS if the review says that RS256 (RSASSA-PKCS1-v1_5), which services/billing/auth.py accepts, doesn't meet ASVS's approved cryptography (for example because Appendix C disallows RSASSA-PKCS1-v1_5 signatures), and also says it is covered by the project's documented exception EXC-007 in docs/security/exceptions.md, keeping it visible as an accepted risk, policy exception or follow-up rather than calling the requirement met.
FAIL if the review calls RS256 compliant, approved or verified against ASVS, ignores EXC-007 and blocks the release on RS256, or doesn't mention the RS256 issue at all.
