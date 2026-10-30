---
type: llm
---

orders.Service in orders/service.go only passes each call to the store and returns the store's result unchanged, while the customer endpoints call their store directly.
PASS if the review reports the service as a layer that adds nothing (a pass-through, forwarding or needless indirection) and recommends that the handler use the store directly or that the layer be removed.
FAIL if it doesn't report it, or recommends adding a service layer to the customers package as well.
