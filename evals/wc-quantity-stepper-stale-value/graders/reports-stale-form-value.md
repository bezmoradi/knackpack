---
type: llm
---

The uncommitted `quantity-stepper` is form-associated but calls `this.#internals.setFormValue` only in `connectedCallback`. The `value` setter, which the plus and minus buttons use, updates the display and fires `change` without calling `setFormValue`, so the form keeps submitting the quantity the element started with: a customer who presses + twice sees 3 but orders 1.
PASS if the review reports that the submitted form value isn't updated when the quantity changes (setFormValue only on connect, not in the setter), so the form submits a different quantity than the one shown, and grades it High, or Medium and blocking.
FAIL if it misses the stale submitted value, says the form submits what's displayed, or grades it Low, or Medium without calling it blocking.
