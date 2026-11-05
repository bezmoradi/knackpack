---
type: llm
---

The uncommitted change renames `product-card`'s `<slot name="heading">` to `<slot name="title">`, but `pages/shoes.html`, `pages/jackets.html` and `pages/packs.html` still mark the product name `slot="heading"`. An element whose `slot` attribute names no slot in the shadow tree is assigned to no slot, not to the default one, so it isn't rendered: every product card loses its name.
PASS if the review reports that the pages' `slot="heading"` content no longer matches any slot, so the product names stop rendering, and grades it Medium or higher. Fixes that update every usage, or keep `heading` as an alias slot, are fine.
FAIL if it misses the mismatch, says unmatched content falls back to the default slot, or grades it Low.
