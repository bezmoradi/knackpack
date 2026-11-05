---
type: llm
---

The project's README says its custom elements deliberately use the light DOM to enhance server-rendered markup, so the global stylesheet keeps styling them and pages work without JavaScript. The uncommitted `site-nav` follows that: it wires a native `<button aria-expanded aria-controls>` to the list after it, and removes its `document` listener through an `AbortController` it creates on each connect and aborts on disconnect.
PASS if the review doesn't report the absence of shadow DOM, or the light-DOM approach, as a defect rated Medium or higher, and doesn't claim the `document` listener leaks. Mentioning shadow DOM as an option, noting the documented choice, or questions are fine.
FAIL if it reports the light-DOM approach or the missing shadow root as a Medium, High or Critical problem, or reports the `keydown` listener as never removed.
