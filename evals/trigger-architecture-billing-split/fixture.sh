#!/bin/bash
# A Go monolith where orders and invoices share one database and one
# transaction, and a design doc proposing to move billing into its own
# service with its own database. The user asks for a hard look at that
# design, which is the architecture reviewer's job.
set -euo pipefail
git init -q -b main
git config user.name "Tomás Ruiz"
git config user.email "tomas@example.com"
mkdir -p docs
cat > go.mod <<'GO'
module example.com/shop

go 1.22
GO
cat > checkout.go <<'GO'
package main

import (
	"context"
	"database/sql"
)

// checkout places an order and issues its invoice in one transaction, so an
// order never exists without its invoice.
func checkout(ctx context.Context, db *sql.DB, customerID string, totalCents int64) (string, error) {
	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		return "", err
	}
	defer tx.Rollback()
	var orderID string
	if err := tx.QueryRowContext(ctx,
		`INSERT INTO orders (customer_id, total_cents) VALUES ($1, $2) RETURNING id`,
		customerID, totalCents).Scan(&orderID); err != nil {
		return "", err
	}
	if _, err := tx.ExecContext(ctx,
		`INSERT INTO invoices (order_id, amount_cents, status) VALUES ($1, $2, 'open')`,
		orderID, totalCents); err != nil {
		return "", err
	}
	return orderID, tx.Commit()
}
GO
cat > refunds.go <<'GO'
package main

import (
	"context"
	"database/sql"
)

// refund cancels an order and voids its invoice together.
func refund(ctx context.Context, db *sql.DB, orderID string) error {
	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if _, err := tx.ExecContext(ctx, `UPDATE orders SET status = 'refunded' WHERE id = $1`, orderID); err != nil {
		return err
	}
	if _, err := tx.ExecContext(ctx, `UPDATE invoices SET status = 'void' WHERE order_id = $1`, orderID); err != nil {
		return err
	}
	return tx.Commit()
}
GO
cat > docs/billing-split.md <<'MD2'
# Proposal: move billing into its own service

## Why
The billing team wants to deploy on its own schedule.

## Design
- A new `billing` service owns the `invoices` table, moved to its own Postgres database.
- `checkout` inserts the order, then calls `POST /invoices` on the billing service.
- `refund` updates the order, then calls `POST /invoices/{id}/void`.
- Calls time out after 2 seconds. On a timeout we log it and return success to the customer.

## Rollout
Copy the invoices table over a weekend, switch the code, drop the old table.
MD2
git add -A
git commit -qm "Shop monolith and billing split proposal"
