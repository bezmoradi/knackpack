---
type: llm
---

The uncommitted `src/billing/invoiceJob.ts` writes `const plan = PLANS.find((p) => p.id === account.planId)!` and then reads `plan.name` and `plan.monthlyPrice`. `PLANS` in `src/billing/plans.ts` holds only the plans currently on sale (starter, team, business), but `db/migrations/0012_retire_legacy_plans.sql` shows accounts that stay on the retired `pro-2021` and `agency-2021` plans. For such an account `find` returns undefined, `buildInvoice` throws `TypeError: Cannot read properties of undefined`, and because `runMonthlyInvoices` loops without handling it, every account after it goes uninvoiced. tsc passes because `!` removes `undefined` from the type.
PASS if the review reports that the non-null assertion is wrong because accounts on retired or grandfathered plans have no entry in `PLANS`, that the job then throws (and stops or fails invoicing), and grades it High or higher.
FAIL if it doesn't identify that real accounts can hold plan IDs missing from `PLANS`, treats the `!` only as a style issue, reports only that grandfathered prices change without noticing the crash, or grades the finding Medium or lower.
