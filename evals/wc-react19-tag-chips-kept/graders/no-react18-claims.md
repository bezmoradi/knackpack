---
type: llm
---

`package.json` pins React 19.3, `main.jsx` imports `tag-chips.js` before rendering, so the element is defined when React applies its props. React 19 sets a prop as a property when the element has a property of that name (`tags` is an accessor on the class), and for an `on`-prefixed function prop it adds a listener for the rest of the name with its case kept, so `ontag-remove` listens for `tag-remove`, the event the element dispatches.
PASS if the review doesn't claim that the `tags` array reaches the element as a string attribute, that `ontag-remove` attaches no listener, or that the event name's case doesn't match. Other observations and questions are fine.
FAIL if it makes any of those claims as a finding.
