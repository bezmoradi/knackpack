---
type: llm
---

`.docs-page__toolbar` is `position: sticky; top: 0` and its parent `.docs-page` scrolls with the page. The change adds `overflow: hidden` to `.docs-page` to clip its new rounded corners, which makes `.docs-page` the toolbar's scroll container. `.docs-page` itself never scrolls (it grows with its content), so the toolbar no longer sticks to the top of the viewport as the page scrolls. `overflow: clip` clips the corners without creating a scroll container.
PASS if the review reports that the new `overflow: hidden` stops the sticky toolbar from sticking, explains it by the ancestor becoming the scroll container (or an equivalent explanation), and grades it Medium or higher.
FAIL if it misses the sticky breakage, or attributes it to something else.
