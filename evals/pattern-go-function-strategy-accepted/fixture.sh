#!/bin/bash
# A Go module where the discount applied to a cart total is a function value,
# with three ready-made discounts. Nothing here needs more than that.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p pricing cmd/quote
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

// Threshold applies d only once the subtotal reaches min.
func Threshold(min int64, d Discount) Discount {
	return func(subtotal int64) int64 {
		if subtotal < min {
			return subtotal
		}
		return d(subtotal)
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
cat > cmd/quote/main.go <<'GO'
// Command quote prints the total for a fixed cart under each discount.
package main

import (
	"fmt"

	"example.com/shop/pricing"
)

func main() {
	var cart pricing.Cart
	for _, cents := range []int64{1999, 2500, 499} {
		cart.Add(cents)
	}
	for name, d := range map[string]pricing.Discount{
		"none":         nil,
		"ten percent":  pricing.Percent(10),
		"five off":     pricing.Flat(500),
		"bulk ten off": pricing.Threshold(4000, pricing.Flat(1000)),
	} {
		fmt.Printf("%-13s %d\n", name, cart.Total(d))
	}
}
GO
git add -A
git commit -qm "Cart totals with a function-valued discount"
