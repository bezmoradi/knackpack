---
type: llm
---

The uncommitted `src/billing/handleEvent.ts` checks `event.type.startsWith("invoice.")` and then writes `const inv = event as InvoicePaid` and calls `markInvoicePaid(inv.data.id, inv.data.amount_paid)`. `src/billing/events.ts` documents and types three invoice events, `invoice.paid`, `invoice.payment_failed` and `invoice.voided`, all of which pass the prefix check. A voided invoice or a failed charge is therefore recorded as paid, with `amountPaid` undefined. tsc accepts the assertion because `InvoicePaid` is a member of the `BillingEvent` union; narrowing with `event.type === "invoice.paid"` would need no assertion.
PASS if the review reports that the prefix check doesn't prove the event is `invoice.paid`, so voided or payment-failed invoices (at least one named, or the other invoice events in general) get marked paid, and grades it High or higher.
FAIL if it doesn't report that non-paid invoice events are marked paid, mentions the assertion only as a style concern, says the assertion is safe because `InvoicePaid` is in the union, or grades the finding Medium or lower.
