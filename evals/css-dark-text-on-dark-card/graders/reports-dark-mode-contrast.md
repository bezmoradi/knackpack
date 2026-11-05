---
type: llm
---

In dark mode, `--color-surface-raised` becomes `#111827` (gray-900), but the change hard-codes the card's text as `#374151` (gray-700) and its title as `#111827`. The body text is then dark gray on near-black, far below 4.5:1, and the title is the same color as the background, so it's invisible. The project already has `--color-text` and `--color-text-muted` tokens that switch with the theme.
PASS if the review reports that the hard-coded text colors don't follow the dark theme while the background token does, so the card's text becomes unreadable or fails contrast in dark mode, and grades it High or Critical, or Medium and blocking, or otherwise calls it blocking.
FAIL if it misses the dark-mode problem, reports the hard-coded colors only as a token-consistency nit without the contrast consequence, or grades it Medium or lower without calling it blocking.
