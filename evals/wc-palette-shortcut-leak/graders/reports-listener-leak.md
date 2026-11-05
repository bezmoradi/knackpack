---
type: llm
---

The uncommitted `command-palette` adds an anonymous `keydown` listener to `document` in `connectedCallback` and has no `disconnectedCallback`. The router replaces the view, and its palette, on every navigation, so each removed palette keeps its listener: after visiting three views, Ctrl+K runs `open()` on three palettes, two of them detached, each fetching `/api/commands` and calling `showModal()`, and `document` keeps every old palette and its shadow tree reachable, so they're never collected.
PASS if the review reports that the document listener is never removed when the palette is disconnected, and names a concrete consequence (detached palettes still handling the shortcut, repeated fetches per keypress growing with navigation, errors from `showModal()` on a disconnected dialog, or the old palettes being kept in memory), and grades it Medium or higher.
FAIL if it misses the missing cleanup, mentions it only as a style preference, or grades it Low.
