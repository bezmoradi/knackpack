---
type: llm
---

The change sets `outline: none` on `:focus` for links, buttons, inputs, selects and textareas, and nothing else in the stylesheet draws a focus state (no border, background, shadow or underline change on focus), so keyboard users can't see which element has focus. That fails WCAG 2.2 success criterion 2.4.7 Focus Visible (Level AA). Keeping the browser's ring for keyboard use with `:focus-visible`, or removing it only with `:focus:not(:focus-visible)`, meets the designers' goal.
PASS if the review reports that keyboard focus becomes invisible, cites focus visibility (2.4.7 or equivalent wording), and grades it High or Critical, or calls it blocking.
FAIL if it misses this, accepts the change, or grades it Medium or lower without calling it blocking.
