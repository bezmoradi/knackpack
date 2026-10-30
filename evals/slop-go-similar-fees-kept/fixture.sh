#!/bin/bash
# A business with invoices and equipment rentals. The uncommitted change adds
# a rental late fee whose arithmetic resembles the invoice late fee; the
# repository's policy notes say the two are set by different teams and change
# independently.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p billing rentals docs
cat > go.mod <<'GO'
module example.com/ops

go 1.22
GO
cat > billing/latefee.go <<'GO'
// Package billing charges invoices.
package billing

// InvoiceLateFee is the fee on an unpaid invoice balance: after a 30-day
// grace period, 1.5% of the balance for each started month overdue, and at
// least $5 once any fee applies.
func InvoiceLateFee(balanceCents int64, daysOverdue int) int64 {
	if daysOverdue <= 30 || balanceCents <= 0 {
		return 0
	}
	months := int64((daysOverdue - 30 + 29) / 30)
	fee := balanceCents * 15 * months / 1000
	return max(fee, 500)
}
GO
cat > rentals/rentals.go <<'GO'
// Package rentals handles equipment rentals.
package rentals
GO
cat > docs/policies.md <<'MD'
# Fees and who owns them

- **Invoice late fees** are set by finance and written into each customer's
  contract. Finance reviews the terms once a year, and a change applies only
  to contracts signed after it.
- **Rental late fees** are set by operations in the rental agreement and
  change with the season and the equipment.

The two are separate policies. Don't share code between them: a change to
one must never change the other.
MD
git add -A
git commit -qm "Invoice late fee and fee ownership notes"
cat > rentals/latefee.go <<'GO'
package rentals

// LateFee is the fee for returning rented equipment late: after a one-day
// grace period, 1.5% of the deposit for each started day late, never more
// than the deposit.
func LateFee(depositCents int64, daysLate int) int64 {
	if daysLate <= 1 || depositCents <= 0 {
		return 0
	}
	days := int64(daysLate - 1)
	fee := depositCents * 15 * days / 1000
	return min(fee, depositCents)
}
GO
