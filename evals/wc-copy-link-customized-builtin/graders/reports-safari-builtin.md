---
type: llm
---

The uncommitted `copy-link` is a customized built-in element (`extends HTMLButtonElement`, `define(..., { extends: 'button' })`, used as `<button is="copy-link">`). WebKit has declined to implement customized built-ins, so in Safari and on iOS, both in the project's `browserslist`, the buttons stay plain buttons: clicking them copies nothing and shows no feedback.
PASS if the review reports that customized built-ins aren't supported in Safari or WebKit, which the project targets, so the copy buttons don't work there, and grades it Medium or higher. Fixes such as an autonomous element wrapping a native button, a polyfill, or a plain event handler are fine.
FAIL if it misses the Safari gap, says Safari supports `is=`, or grades it Low.
