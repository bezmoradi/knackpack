---
type: llm
---

The package's README promises no runtime dependencies and says every element is a plain `HTMLElement` subclass; both existing elements are. The uncommitted change adds `lit` to `dependencies` for `count-badge`, which only shows a number, so every consumer now installs Lit, and an app that uses another Lit version can end up with two copies. A plain `HTMLElement` with a `count` property and a text node does the same job.
PASS if the review reports that adding `lit` as a runtime dependency breaks the package's documented zero-dependency promise or adds a dependency this simple badge doesn't need (pointing to the plain `HTMLElement` pattern the package already uses), at any severity below Critical.
FAIL if it doesn't mention the new dependency as a problem, endorses adding Lit to this package without noting the README's promise, or grades it Critical.
