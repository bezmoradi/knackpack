---
type: llm
---

The uncommitted `search-field` copies the host's `aria-labelledby="site-search-label"` onto the `<input>` inside its shadow root. ID references resolve only within the same tree, and `site-search-label` is in the document, so the reference finds nothing and the search box has no accessible name (WCAG 4.1.2 Name, Role, Value, Level A). The host's own `aria-labelledby` names only the host, which has no role, not the input users type into.
PASS if the review reports that the input's `aria-labelledby` can't reach an element outside the shadow root, so the search input is unnamed for assistive technology, and grades it Medium or higher. Any workable fix (copying the label text into the shadow root, an `aria-label`, a slotted or internal label, element reflection where supported) is fine.
FAIL if it misses the cross-root reference, says the copied attribute names the input, or grades it Low.
