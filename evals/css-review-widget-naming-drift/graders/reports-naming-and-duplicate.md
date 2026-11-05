---
type: llm
---

The package documents lowercase kebab-case `block__element--modifier` names with `is-`/`has-` state classes, and the existing components follow it. The new widget uses camelCase blocks (`.reviewWidget`, `.starRow`), a generic `.title` and `.star` under descendant selectors, and a bare global `.active` class that will style anything else named `active` wherever the package's CSS loads. Its `.reviewWidget` rule declares `padding` twice with different values, so the first is dead.
PASS if the review reports both (a) that the new class names break the project's documented convention, or that `.active` (or another generic name) can leak and style other elements, and (b) the duplicate `padding` declaration; and grades no naming or duplicate finding above Medium.
FAIL if it misses either (a) or (b), or grades a naming or duplicate-declaration finding High or Critical.
