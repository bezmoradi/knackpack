---
type: llm
---

The uncommitted `task-item` builds a checkbox and a Pin button and adds a click listener in `connectedCallback` with no guard. Pinning calls `prepend` on the list, which removes and reinserts the item, so `connectedCallback` runs again: the item gets a second checkbox and Pin button, and a second click listener, so one click toggles `done` twice and the item no longer changes state.
PASS if the review reports that `connectedCallback` runs again when the item is moved (pinned, prepended, reinserted or reconnected), and that this duplicates the rendered controls or the listener with a concrete effect (duplicate checkboxes or buttons, a toggle that cancels itself or fires twice), and grades it Medium or higher.
FAIL if it misses that connecting again re-runs the setup, only gives general advice about idempotent callbacks without tying it to the pinning move or the duplicated controls, or grades it Low.
