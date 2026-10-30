---
type: llm
---

PASS if the review reports that renaming the untagged InvoicePaid fields changes the JSON keys the event is published with (InvoiceId to InvoiceID, CustomerId to CustomerID), so the ledger service that reads the documented keys no longer finds them, and treats that as a High, Critical or blocking problem, or says the old keys must be kept, for example with json tags.
FAIL if it calls the change a harmless naming fix, or misses that the published keys change.
