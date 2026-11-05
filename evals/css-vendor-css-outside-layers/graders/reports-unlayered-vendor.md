---
type: llm
---

The app declares `@layer reset, base, components, utilities` and imports its own CSS into layers. The change imports the date picker's stylesheet with no `layer()`, so its rules are unlayered, and unlayered normal declarations beat every layered declaration whatever their specificity. That stylesheet contains global `button { background: none; border: 0; padding: 0; color: inherit }` and `a { color: inherit; text-decoration: none }` rules, so every `.button` and `.button--ghost` in the app loses its background, border and padding, and every link loses its color, not just inside the calendar. Importing it into a layer (for example `layer(vendor)` placed before `components`) keeps it below the app's styles.
PASS if the review reports that the vendor import is unlayered and therefore overrides the layered app styles, names the app-wide effect on buttons or links, and grades it High or Critical, or Medium and blocking, or otherwise calls it blocking.
FAIL if it misses that unlayered CSS beats layered CSS, treats it as a specificity question the layered `.button` class would win, or grades it Medium or lower without calling it blocking.
