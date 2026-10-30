#!/bin/bash
# A shop whose cart preview and checkout both charge the flat shipping fee
# from the pricing package. The uncommitted change makes shipping free from
# $50 by copying the same threshold check into both.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p pricing cart checkout
cat > go.mod <<'GO'
module example.com/shop

go 1.22
GO
cat > pricing/pricing.go <<'GO'
// Package pricing holds the shop's prices and charges.
package pricing

// ShippingCents is the flat shipping charge for an order.
const ShippingCents = 499
GO
cat > cart/preview.go <<'GO'
// Package cart shows customers what their cart will cost.
package cart

import "example.com/shop/pricing"

// Item is one line in the cart.
type Item struct {
	PriceCents int64
	Qty        int64
}

// Summary is what the cart page shows.
type Summary struct {
	SubtotalCents int64
	ShippingCents int64
	TotalCents    int64
}

// Preview totals the items the way checkout will charge them.
func Preview(items []Item) Summary {
	var subtotal int64
	for _, it := range items {
		subtotal += it.PriceCents * it.Qty
	}
	shipping := int64(pricing.ShippingCents)
	return Summary{SubtotalCents: subtotal, ShippingCents: shipping, TotalCents: subtotal + shipping}
}
GO
cat > checkout/checkout.go <<'GO'
// Package checkout charges orders.
package checkout

import "example.com/shop/pricing"

// Order is an order about to be charged.
type Order struct {
	SubtotalCents int64
	ShippingCents int64
	TotalCents    int64
}

// Finalize sets the order's shipping charge and total.
func Finalize(o Order) Order {
	o.ShippingCents = pricing.ShippingCents
	o.TotalCents = o.SubtotalCents + o.ShippingCents
	return o
}
GO
git add -A
git commit -qm "Cart preview and checkout with flat shipping"
cat > cart/preview.go <<'GO'
// Package cart shows customers what their cart will cost.
package cart

import "example.com/shop/pricing"

// Item is one line in the cart.
type Item struct {
	PriceCents int64
	Qty        int64
}

// Summary is what the cart page shows.
type Summary struct {
	SubtotalCents int64
	ShippingCents int64
	TotalCents    int64
}

// Preview totals the items the way checkout will charge them.
func Preview(items []Item) Summary {
	var subtotal int64
	for _, it := range items {
		subtotal += it.PriceCents * it.Qty
	}
	shipping := int64(pricing.ShippingCents)
	if subtotal >= 5000 {
		shipping = 0
	}
	return Summary{SubtotalCents: subtotal, ShippingCents: shipping, TotalCents: subtotal + shipping}
}
GO
cat > checkout/checkout.go <<'GO'
// Package checkout charges orders.
package checkout

import "example.com/shop/pricing"

// Order is an order about to be charged.
type Order struct {
	SubtotalCents int64
	ShippingCents int64
	TotalCents    int64
}

// Finalize sets the order's shipping charge and total. Orders of $50 or
// more ship free.
func Finalize(o Order) Order {
	o.ShippingCents = pricing.ShippingCents
	if o.SubtotalCents >= 5000 {
		o.ShippingCents = 0
	}
	o.TotalCents = o.SubtotalCents + o.ShippingCents
	return o
}
GO
