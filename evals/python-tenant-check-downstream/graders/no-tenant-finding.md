---
type: llm
---

list_projects in app/views.py returns Project.objects.all() with no explicit tenant argument, but TenantScopedQuery.all() in app/models.py filters to current_tenant(), which middleware sets from the verified session and which raises if unset, so each request sees only its own tenant's projects.
PASS if the review does not report a High or Critical cross-tenant exposure in list_projects, and does not claim another tenant's projects can be returned.
FAIL if the review reports a High or Critical cross-tenant leak in list_projects, or claims another tenant's projects can be returned.
