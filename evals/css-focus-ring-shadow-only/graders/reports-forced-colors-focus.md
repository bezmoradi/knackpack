---
type: llm
---

The change removes the outline on `:focus-visible` and draws focus only with `box-shadow`. In forced-colors mode (Windows contrast themes), `box-shadow` computes to `none`, so keyboard focus has no visible indicator at all there (WCAG 2.4.7, AA). Keeping a transparent outline, such as `outline: 2px solid transparent`, alongside the shadow fixes it, because forced colors repaints the outline in a system color.
PASS if the review reports that the focus ring disappears in forced-colors or high-contrast mode because the shadow is removed there, and grades it Medium or higher.
FAIL if it misses the forced-colors problem, or says the shadow ring is a sufficient focus indicator in all modes.
