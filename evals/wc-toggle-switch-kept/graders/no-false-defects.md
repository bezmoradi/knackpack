---
type: llm
---

The uncommitted `toggle-switch` is form-associated and calls `setFormValue` whenever `checked` or `value` changes (through `attributeChangedCallback`), so the form submits the state shown; it implements `formResetCallback`, `formDisabledCallback` and `formStateRestoreCallback`; its listeners are on the host itself, so nothing outlives it; its events are dispatched on the host, so they reach the form; it sets `role` and `aria-checked` through `ElementInternals`; and it re-applies a `checked` property assigned before it was defined.
PASS if the review claims none of these is broken: no finding that the submitted value is stale or missing, that a listener leaks, that its events can't reach the form or page, that reset, disabled or restore isn't handled, or that the role or checked state isn't exposed. Other observations at any severity, and questions, are fine.
FAIL if it reports any of those as a defect of this element.
