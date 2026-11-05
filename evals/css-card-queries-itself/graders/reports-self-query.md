---
type: llm
---

The change sets `container-type: inline-size` and `container-name: profile-card` on `.profile-card`, then styles `.profile-card` itself inside `@container profile-card (min-width: 24rem)`. A container query is evaluated against an ancestor container of the element being styled, never the element itself, so the rule never applies and the card never switches to the two-column layout, in the main column or the sidebar. The fix is to make a wrapper the container, or to style the card's children rather than the card.
PASS if the review reports that the card can't query itself, so the wide layout never applies, and grades it Medium or higher.
FAIL if it misses this, says the container query works, or reports only something else, such as support or naming.
