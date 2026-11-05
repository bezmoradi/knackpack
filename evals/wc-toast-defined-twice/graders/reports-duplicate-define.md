---
type: llm
---

`src/components/app-toast.js` and the uncommitted `widgets/support-chat/vendor/app-toast.js` both call `customElements.define('app-toast', ...)`. The page loads `src/main.js` first, so the vendored module's `define` throws a `NotSupportedError`; because that module is a static import of `chat.js`, `chat.js` never evaluates, `support-chat` is never defined and the chat button never appears.
PASS if the review reports that the tag is registered twice, that the second `define` throws, and a concrete consequence of it (the chat widget's module failing so `support-chat` never works, or one copy's toast failing), and grades it Medium or higher.
FAIL if it misses the duplicate registration, says the second definition silently replaces or is ignored by the first, or grades it Low.
