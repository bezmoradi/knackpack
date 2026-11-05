---
type: llm
---

The app ships Arabic and Hebrew, and the layout template sets `dir` from the locale. The rest of the stylesheet uses logical properties. The change adds `margin-right: 2.5rem` and `text-align: left` on the text column and positions the badge with `right: 1rem`, all physical: under `dir="rtl"` the flex row reverses, so the reserved space sits on the wrong side, names and previews align against the reading direction, and the badge stays at the right edge on top of the avatar instead of at the end of the row.
PASS if the review reports that these physical properties break the right-to-left (Arabic or Hebrew) layout, explains at least one concrete effect such as the badge overlapping or the text aligned the wrong way, recommends logical equivalents (such as `inset-inline-end`, `margin-inline-end`, `text-align: start`), and grades it Medium or higher.
FAIL if it misses the RTL problem, or calls the physical properties only a style preference without saying the app ships right-to-left locales.
