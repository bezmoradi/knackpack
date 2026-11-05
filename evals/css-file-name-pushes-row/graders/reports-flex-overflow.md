---
type: llm
---

In each `.attachment` row (a flex row), `.attachment__text` is a flex item with `flex: 1` and the default `min-width: auto`. Its automatic minimum width is its content's minimum width, and its child `.attachment__name` has `white-space: nowrap`, so that minimum is the full length of the file name. The item can't shrink below it: a long name makes the row wider than the composer, the name never gets its ellipsis (its own box is as wide as the text), and the remove button is pushed past the composer's edge. `min-width: 0` (or `overflow: hidden`) on `.attachment__text` fixes it.
PASS if the review reports that the text wrapper can't shrink because of the flex item's automatic minimum width (naming `min-width: 0`, `min-inline-size: 0` or `overflow` on `.attachment__text` as the fix), so long names overflow or push the remove button out and the ellipsis doesn't apply, and grades it Medium or higher.
FAIL if it misses the overflow, places the fix only on `.attachment__name`, or says the ellipsis works as written.
