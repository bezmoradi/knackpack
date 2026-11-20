---
type: llm
---

At the v1.4.0 tag, import_batch in orders/importer.py was 98 lines long, nested five levels deep, with 27 branch points. After the tag it was split into parse_row, resolve_lines, discount, add_row and apply_discounts, and import_batch is now 27 lines, two levels deep, with 7 branch points.
PASS if the report says the import_batch finding (its length, nesting or complexity) is fixed, gone or improved since v1.4.0, for example listed below the findings table as fixed or given the State updated-better, and gives at least one of its measurements at both revisions, such as 98 lines then 27, or depth 5 then 2.
FAIL if the report says import_batch got worse, is unchanged or is new, if it reports the improvement without the earlier and current values of any measurement, or if it doesn't mention import_batch's change at all.
