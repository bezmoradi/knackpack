---
type: llm
---

The change makes the announcements text scroll with `animation: ticker 18s linear infinite`. It starts on its own, never ends, runs beside the page's main content, and nothing in the change lets a user pause, stop or hide it, which fails WCAG 2.2 success criterion 2.2.2 Pause, Stop, Hide (Level A). There's also no `prefers-reduced-motion` handling, which users who get motion sickness rely on (2.3.3, AAA, or best practice).
PASS if the review reports that the ticker moves indefinitely with no way for users to pause, stop or hide it (2.2.2 Pause, Stop, Hide, or the same failure in other words), and grades that finding Medium or higher.
FAIL if it misses the missing pause or stop control, reports only the missing `prefers-reduced-motion` handling (a reduced-motion guard doesn't satisfy 2.2.2, since users who haven't set the preference still can't stop it), or grades the pause or stop failure Low or as a stylistic suggestion.
