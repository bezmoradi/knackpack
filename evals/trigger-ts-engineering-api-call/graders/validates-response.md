---
type: llm
---

src/catalog.ts already validates book responses with an `isBook` guard on an `unknown` body. The new `getAvailability` reads the availability JSON (sample: `onShelf` a number, `nextDue` a date string, which may be absent or null when nothing is on loan, though the sample doesn't say).
PASS if the new function checks the parsed response at run time before returning it: a type guard, explicit `typeof` checks of the fields it returns, or a schema, so a response with a missing or wrong-typed `onShelf` is rejected or handled rather than returned as a number.
FAIL if it only annotates or casts the JSON (`as Availability`, `const body: Availability = await res.json()`, a generic on a fetch helper) and returns its fields unchecked, or if the function wasn't added.
