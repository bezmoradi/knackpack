---
type: llm
---

The uncommitted `card-fields` relies on `mode: 'closed'` to keep card numbers from the third-party analytics and chat scripts the page loads. A closed shadow root only hides the root from `element.shadowRoot`; it isn't a security boundary. Scripts running in the same page can replace `Element.prototype.attachShadow` before the element is defined and keep the root, call the public `getCardData()` method, or listen to the composed `keydown` and `input` events typed into the fields.
PASS if the review reports that the closed shadow root doesn't protect the card data from other scripts on the same page, names at least one concrete way they can still get it (patching `attachShadow`, the public `getCardData()`, composed keyboard or input events, or anything equivalent), and grades the false protection Medium or higher. Recommending an isolated payment iframe from the processor, or removing the untrusted scripts from the checkout page, is fine.
FAIL if it accepts the closed root as protecting the fields, only criticizes closed mode for testing or styling reasons, or grades the security point Low.
