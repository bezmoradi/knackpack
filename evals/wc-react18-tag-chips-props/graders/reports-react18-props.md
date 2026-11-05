---
type: llm
---

`package.json` pins React 18.3 (`^18.3.1`). React 18 sets every prop on a custom element with `setAttribute`, so `tags={tags}` becomes the attribute `tags="work,urgent,q3"` and never reaches the element's `tags` property, which `tag-chips` needs to render: no chips appear. React 18 also drops an `on`-prefixed function prop it doesn't know, so `ontag-remove` adds no `tag-remove` listener and removing a tag would do nothing. React 19 changed both, which is what the React documentation now describes.
PASS if the review reports that, under the project's React 18, the array is passed as an attribute string rather than the property (so the chips don't render) and that the `ontag-remove` handler isn't attached, and grades it High, or Medium and blocking. Fixes such as setting the property and adding the listener through a ref in an effect, a wrapper, or upgrading to React 19 are fine.
FAIL if it says React 18 sets the property or attaches the listener, judges the code only against React 19 behavior, misses either half, or grades it Low, or Medium without calling it blocking.
