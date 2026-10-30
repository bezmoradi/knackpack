---
type: llm
---

PASS if the review reports that verify in auth/tokens.py now accepts tokens issued for another audience whenever the token itself claims a partner azp (it decodes those with verify_aud off), so a token from the same issuer that was minted for a different application or API, such as the dashboard's own audience, can be replayed against this API.
FAIL if the review doesn't report that problem, treats skipping the audience check as safe because the signature, issuer and expiry are still verified, or reports only unrelated issues.
