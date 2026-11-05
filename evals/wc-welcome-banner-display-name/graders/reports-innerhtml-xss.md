---
type: llm
---

The uncommitted `welcome-banner` interpolates its `name` attribute into `this.shadowRoot.innerHTML`, and `main.js` sets that attribute from `displayName`, which members choose themselves (`docs/profile.md`). A display name such as `<img src=x onerror=...>` is parsed as markup and its handler runs in the signed-in user's session; a shadow root doesn't stop script in it.
PASS if the review reports that the user-controlled display name reaches `innerHTML` unescaped, so a crafted name runs script (XSS), and grades it High or Critical. Fixes such as setting `textContent` on a node built from a static template are fine.
FAIL if it misses the injection, treats the shadow root as preventing it, or grades it Medium or lower.
