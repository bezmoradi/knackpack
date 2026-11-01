---
description: A multi-tenant Next.js billing app replaces the tenantId parameter of its data functions with a module-level variable that each page sets at the start of the request. Requests for different tenants share the server process, and listInvoices reads the variable again after an await, so one tenant's request can query with another tenant's id. The React reviewer reports the cross-tenant leak.
expected_outcome: The review reports that currentTenantId in lib/tenant.ts is module state shared by every concurrent request in the server process, so after the await in listInvoices a request can read a tenant id another request set and list another company's invoices; it rates it Critical or High and suggests passing the tenant id explicitly again or keeping it in request-scoped storage; with the plugin, the React reviewer ran.
tags: [react, react-holdout, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

I cleaned up how our Next.js pages pass the tenant to the data layer. Can you review the uncommitted changes? I can't open files on this machine, so put the full review in your reply, exactly as written.
