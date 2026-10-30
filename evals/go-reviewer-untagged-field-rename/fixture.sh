#!/bin/bash
# A billing service that publishes an InvoicePaid event as JSON with untagged
# fields, documented for a consumer in another service, plus an uncommitted
# rename of those fields to Go's initialism style, which changes the keys.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p events payments docs
cat > go.mod <<'GO'
module example.com/billing

go 1.22
GO
cat > docs/events.md <<'MD'
# Events billing publishes

## InvoicePaid

Published as JSON to the `invoice-paid` topic each time an invoice is paid.
The ledger service, written in TypeScript, consumes it and reads these keys:

    {"InvoiceId": "inv_123", "CustomerId": "cus_456", "AmountCents": 4200}
MD
cat > events/invoice.go <<'GO'
// Package events defines the messages billing publishes for other services.
package events

import "encoding/json"

// InvoicePaid is published as JSON each time an invoice is paid; see
// docs/events.md for its consumers.
type InvoicePaid struct {
	InvoiceId   string
	CustomerId  string
	AmountCents int64
}

// Encode returns the JSON body published for e.
func Encode(e InvoicePaid) ([]byte, error) {
	return json.Marshal(e)
}
GO
cat > payments/pay.go <<'GO'
// Package payments marks invoices paid and announces it.
package payments

import (
	"context"

	"example.com/billing/events"
)

// Publisher sends one encoded event to a topic.
type Publisher interface {
	Publish(ctx context.Context, topic string, body []byte) error
}

// MarkPaid announces that invoiceID, owed by customerID, was paid.
func MarkPaid(ctx context.Context, pub Publisher, invoiceID, customerID string, amountCents int64) error {
	body, err := events.Encode(events.InvoicePaid{
		InvoiceId:   invoiceID,
		CustomerId:  customerID,
		AmountCents: amountCents,
	})
	if err != nil {
		return err
	}
	return pub.Publish(ctx, "invoice-paid", body)
}
GO
git add -A
git commit -qm "Publish InvoicePaid events"
cat > events/invoice.go <<'GO'
// Package events defines the messages billing publishes for other services.
package events

import "encoding/json"

// InvoicePaid is published as JSON each time an invoice is paid; see
// docs/events.md for its consumers.
type InvoicePaid struct {
	InvoiceID   string
	CustomerID  string
	AmountCents int64
}

// Encode returns the JSON body published for e.
func Encode(e InvoicePaid) ([]byte, error) {
	return json.Marshal(e)
}
GO
cat > payments/pay.go <<'GO'
// Package payments marks invoices paid and announces it.
package payments

import (
	"context"

	"example.com/billing/events"
)

// Publisher sends one encoded event to a topic.
type Publisher interface {
	Publish(ctx context.Context, topic string, body []byte) error
}

// MarkPaid announces that invoiceID, owed by customerID, was paid.
func MarkPaid(ctx context.Context, pub Publisher, invoiceID, customerID string, amountCents int64) error {
	body, err := events.Encode(events.InvoicePaid{
		InvoiceID:   invoiceID,
		CustomerID:  customerID,
		AmountCents: amountCents,
	})
	if err != nil {
		return err
	}
	return pub.Publish(ctx, "invoice-paid", body)
}
GO
