---
type: llm
---

The effect in src/CustomerSearch.tsx starts a 250 ms timer that calls searchCustomers(query) and sets the results when it resolves; its cleanup only clears the timer. searchCustomers accepts an AbortSignal that the effect never passes, and src/api.ts says short queries answer slower than long ones.
PASS if the review reports that responses can arrive out of order: once a request has started, the cleanup doesn't cancel or ignore it, so a slower response for an earlier query (such as "ma") can resolve after the one for the current query (such as "mar") and overwrite the results, leaving the list showing customers for text the user no longer has in the box. It must say the debounce doesn't prevent this. A fix that ignores stale results with a flag set in the cleanup, aborts with an AbortController, or uses a data library keyed by the query is expected.
FAIL if the review doesn't report this race, or says the debounce or the timer cleanup already prevents it.
