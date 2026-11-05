---
type: llm
---

The uncommitted `info-disclosure` has a getter that returns `this.hasAttribute('open')` and a setter that calls `this.setAttribute('open', value)`. Setting `open = false` (the Close button, or the toggle on an open panel) writes `open="false"`; the attribute is still present, so the getter returns `true`, `:host([open])` keeps the panel visible and `aria-expanded` stays `true`. Once opened, a panel can never be closed.
PASS if the review reports that setting the property to false leaves the attribute present (as the string "false") instead of removing it, so the element stays open and the close or toggle action fails, and grades it Medium or higher. Fixes with `toggleAttribute('open', Boolean(value))` or `removeAttribute` are fine.
FAIL if it misses this, says `setAttribute('open', false)` removes or disables the attribute, or grades it Low.
