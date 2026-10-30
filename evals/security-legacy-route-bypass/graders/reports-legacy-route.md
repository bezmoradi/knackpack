---
type: llm
---

PASS if the review reports that the change makes the retired v1 invoice route (GET /v1/invoices/{invoice_id} in api/v1/invoices.py) reachable again, because build_routes in api/app.py now registers every module under api/ and gateway/routes.yaml now forwards every path, and that the v1 get_invoice skips the invoices:read scope check or the tenant check that the v2 get_invoice enforces, so a signed-in user can read another tenant's invoices.
FAIL if the review doesn't report that the v1 route becomes reachable, or reports it without saying that the v1 handler lacks the scope or tenant check that v2 has.
