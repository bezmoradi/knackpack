---
type: llm
---

The change adds Status.ON_HOLD for paid orders that support pauses, and docs/support.md says checks can take weeks. jobs/purge_abandoned.py, which the change doesn't touch, deletes every order untouched for 30 days whose status isn't in KEEP = {PAID, SHIPPED}.
PASS if the review reports that the cleanup job will delete orders on hold for more than 30 days, which are paid orders, because its filter treats every status outside PAID and SHIPPED as abandoned, and rates it High or Critical or says it blocks.
FAIL if the review doesn't connect the new status to jobs/purge_abandoned.py, or reports it only as a pre-existing or out-of-scope note without saying the change makes held orders deletable.
