---
type: llm
---

The uncommitted `date-field` calls `this.#internals.setFormValue` and `setValidity` but its class never declares `static formAssociated = true`. On an element that isn't form-associated those methods throw `NotSupportedError`, so `connectedCallback` throws on its first `#update()` (before the change listener is even added), the date is never submitted under `date`, and the `required` check never stops the booking form from submitting without a date.
PASS if the review reports the missing `static formAssociated = true` and its consequence (the internals form calls throw, or the date isn't submitted, or required validation doesn't apply), and grades it High, or Medium and blocking.
FAIL if it misses that the element isn't form-associated, says the calls work without the flag, or grades it Low, or Medium without calling it blocking.
