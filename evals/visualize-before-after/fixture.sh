#!/bin/bash
# A small Go checkout package in two commits. In the first, Total takes the
# discount off the subtotal plus shipping, with no cap and no expiry check,
# then adds tax on the whole. The second commit, the last one, checks the
# code's expiry, caps the percentage at 50, takes it off the items subtotal
# only, taxes the discounted subtotal and adds shipping untaxed at the end.
set -euo pipefail
export GIT_AUTHOR_DATE="2026-11-03T11:00:00Z" GIT_COMMITTER_DATE="2026-11-03T11:00:00Z"
git init -q -b main
git config user.name "Alex Morgan"
git config user.email "alex@example.com"
mkdir -p checkout

cat > go.mod <<'EOF'
module example.com/shop

go 1.23
EOF

cat > README.md <<'EOF'
# shop

The shop's checkout. `checkout.Total` prices a cart for the payment step.
Amounts are in cents; tax rates are in basis points.
EOF

cat > checkout/cart.go <<'EOF'
package checkout

// Money is an amount in cents.
type Money int64

type Item struct {
	SKU      string
	Price    Money
	Quantity int
}

type Cart struct {
	Items    []Item
	Shipping Money
	Country  string
}

func (c Cart) Subtotal() Money {
	var s Money
	for _, it := range c.Items {
		s += it.Price * Money(it.Quantity)
	}
	return s
}
EOF

cat > checkout/discounts.go <<'EOF'
package checkout

import (
	"errors"
	"time"
)

var ErrUnknownCode = errors.New("checkout: unknown discount code")

type Discount struct {
	Code      string
	Percent   int
	ExpiresAt time.Time
}

var discounts = map[string]Discount{
	"WELCOME10": {Code: "WELCOME10", Percent: 10, ExpiresAt: time.Date(2027, 1, 1, 0, 0, 0, 0, time.UTC)},
	"STAFF60":   {Code: "STAFF60", Percent: 60, ExpiresAt: time.Date(2027, 6, 1, 0, 0, 0, 0, time.UTC)},
	"BF2025":    {Code: "BF2025", Percent: 25, ExpiresAt: time.Date(2025, 12, 1, 0, 0, 0, 0, time.UTC)},
}

func lookupDiscount(code string) (Discount, error) {
	d, ok := discounts[code]
	if !ok {
		return Discount{}, ErrUnknownCode
	}
	return d, nil
}

// taxRate is the VAT rate for a country in basis points.
func taxRate(country string) Money {
	switch country {
	case "DE":
		return 1900
	case "FR":
		return 2000
	default:
		return 0
	}
}
EOF

cat > checkout/total.go <<'EOF'
package checkout

// Total is what the customer pays: the cart with shipping, less the
// discount, plus tax.
func Total(c Cart, code string) (Money, error) {
	total := c.Subtotal() + c.Shipping
	if code != "" {
		d, err := lookupDiscount(code)
		if err != nil {
			return 0, err
		}
		total -= total * Money(d.Percent) / 100
	}
	tax := total * taxRate(c.Country) / 10000
	return total + tax, nil
}
EOF

git add -A
git commit -qm "Checkout totals with discount codes and VAT"

export GIT_AUTHOR_DATE="2026-11-20T16:40:00Z" GIT_COMMITTER_DATE="2026-11-20T16:40:00Z"

cat > checkout/total.go <<'EOF'
package checkout

import (
	"errors"
	"time"
)

var ErrCodeExpired = errors.New("checkout: discount code expired")

// maxPercent caps any discount code.
const maxPercent = 50

// Total is what the customer pays: the items less the discount, plus tax on
// them, plus shipping, which is neither discounted nor taxed.
func Total(c Cart, code string, now time.Time) (Money, error) {
	items := c.Subtotal()
	if code != "" {
		d, err := lookupDiscount(code)
		if err != nil {
			return 0, err
		}
		if now.After(d.ExpiresAt) {
			return 0, ErrCodeExpired
		}
		pct := d.Percent
		if pct > maxPercent {
			pct = maxPercent
		}
		items -= items * Money(pct) / 100
	}
	tax := items * taxRate(c.Country) / 10000
	return items + tax + c.Shipping, nil
}
EOF

git add -A
git commit -qm "Discounts: items only, capped at 50%, expired codes rejected"
