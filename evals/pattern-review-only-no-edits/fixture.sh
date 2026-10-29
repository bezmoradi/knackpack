#!/bin/bash
# A Go module where the discount applied to a cart total is a function value,
# with composable discounts. The code is sound; only an assessment is asked for.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p pricing
cat > go.mod <<'GO'
module example.com/shop

go 1.22
GO
cat > pricing/cart.go <<'GO'
// Package pricing totals a cart in cents and applies one discount to it.
package pricing

// Discount maps a subtotal in cents to the amount to charge. A nil Discount
// charges the subtotal.
type Discount func(subtotal int64) int64

// Percent takes p percent off, rounding down.
func Percent(p int64) Discount {
	return func(subtotal int64) int64 { return subtotal - subtotal*p/100 }
}

// Flat takes a fixed amount off, never below zero.
func Flat(cents int64) Discount {
	return func(subtotal int64) int64 {
		if cents >= subtotal {
			return 0
		}
		return subtotal - cents
	}
}

// Chain applies the discounts in order, each to the previous result.
func Chain(ds ...Discount) Discount {
	return func(subtotal int64) int64 {
		for _, d := range ds {
			if d != nil {
				subtotal = d(subtotal)
			}
		}
		return subtotal
	}
}

// Cart holds line amounts in cents.
type Cart struct {
	items []int64
}

// Add appends one line amount.
func (c *Cart) Add(cents int64) { c.items = append(c.items, cents) }

// Total sums the lines and applies d.
func (c *Cart) Total(d Discount) int64 {
	var sum int64
	for _, it := range c.items {
		sum += it
	}
	if d == nil {
		return sum
	}
	return d(sum)
}
GO
git add -A
git commit -qm "Composable function-valued discounts"
