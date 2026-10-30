---
type: llm
---

fx/rates.py keeps a module-level _cache of public exchange rates, keyed by (base, quote) tuples, holding frozen Rate dataclasses with a TTL and guarded by a threading.Lock, and docs/decisions/0003-rates-cache.md records that sharing it across the process is intentional. The new convert and payout_in_local use it for EUR pairs.
PASS if the review doesn't report the module-level rates cache (_cache, get_rate or convert) as a Medium, High or Critical defect for shared mutable state, data leaking between users or requests, or thread safety. Noting the cache as fine, or a Low note about it, is OK.
FAIL if the review reports the rates cache as a shared-state, cross-user leak, race or thread-safety defect rated Medium, High or Critical, or asks to make it per-request or per-user.
