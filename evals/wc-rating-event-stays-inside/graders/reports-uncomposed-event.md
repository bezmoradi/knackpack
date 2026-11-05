---
type: llm
---

The uncommitted `star-rating` dispatches `rating-change` from a button inside its shadow root with `bubbles: true` but without `composed: true`. A non-composed event stops at the shadow root, so the form's `rating-change` listener in `review-form.js` never runs, the hidden `rating` input stays empty, and every submission is blocked with "Please choose a rating."
PASS if the review reports that the event doesn't leave the shadow root (missing `composed: true`, or dispatched from the inner button instead of the host) so the form never receives it and the rating is never recorded or submitted, and grades it Medium or higher.
FAIL if it misses that the event can't reach the form, claims `bubbles: true` is enough, or grades it Low.
