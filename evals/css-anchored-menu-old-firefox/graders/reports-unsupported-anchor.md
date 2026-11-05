---
type: llm
---

The project's browserslist includes `Firefox ESR`, `Firefox >= 128`, `Safari >= 17` and `iOS >= 17`. CSS anchor positioning (`anchor-name`, `position-anchor`, `anchor()`, `position-try-fallbacks`) shipped in Firefox 147 and Safari 26, so Firefox 128 to 146 and Safari or iOS 17 to 18 drop those declarations. The popover is then positioned with `inset: auto` and no anchor, so it isn't placed under its button (it falls back to its static or default position), while the change removed the JavaScript positioning that worked everywhere. There's no `@supports` guard or fallback position.
PASS if the review reports that anchor positioning is unsupported in some of the declared target browsers (naming Firefox ESR or 128, or Safari 17, or "older Firefox and Safari" against the browserslist), that the menu is misplaced there without a fallback, and grades it Medium or higher.
FAIL if it misses the support gap, says the feature is supported by all the declared targets, or judges support without reference to the project's targets.
