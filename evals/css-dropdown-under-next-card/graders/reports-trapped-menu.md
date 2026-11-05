---
type: llm
---

Each `.product-card` has `will-change: transform` (and `transform` on hover), which makes every card its own stacking context. The change's `.product-card__menu` has `z-index: 1000`, but that only orders it inside its own card, so when the menu opens near the bottom of a card it renders under the next card in the grid, whose content covers the menu's links.
PASS if the review reports that the menu can't rise above the neighboring card because the card's `will-change` or `transform` creates a stacking context that traps its `z-index`, and grades it High or Critical, or Medium and blocking, or otherwise calls it blocking.
FAIL if it misses this, treats `z-index: 1000` as sufficient, blames something else for the overlap, or grades it Medium or lower without calling it blocking.
