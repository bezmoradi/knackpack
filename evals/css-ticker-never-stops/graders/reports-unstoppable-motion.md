---
type: llm
---

The change makes the announcements text scroll with `animation: ticker 18s linear infinite`. It starts on its own, never ends, runs beside the page's main content, and nothing in the change lets a user pause, stop or hide it, which fails WCAG 2.2 success criterion 2.2.2 Pause, Stop, Hide (Level A). There's also no `prefers-reduced-motion` handling, which users who get motion sickness rely on (2.3.3, AAA, or best practice).
PASS if the review reports that the ticker moves indefinitely with no way for users to pause or stop it, or that it ignores reduced-motion preferences, and grades that finding Medium or higher.
FAIL if it misses the motion problem entirely, or reports it only as Low or as a stylistic suggestion.
