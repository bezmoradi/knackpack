#!/bin/bash
# An invoicing package in a module whose CI runs golangci-lint with its
# default linters, which include unused. The uncommitted change adds the
# 30-day due date the task asked for, plus an unexported business-day helper
# that nothing calls, which that linter fails.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p invoice .github/workflows
cat > go.mod <<'GO'
module example.com/billing

go 1.22
GO
cat > .golangci.yml <<'YML'
version: "2"
linters:
  enable:
    - misspell
formatters:
  enable:
    - gofmt
YML
cat > .github/workflows/ci.yml <<'YML'
name: ci
on:
  push:
  pull_request:
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version-file: go.mod
      - run: go test ./...
      - uses: golangci/golangci-lint-action@v8
        with:
          version: v2.14
YML
cat > invoice/invoice.go <<'GO'
// Package invoice builds invoices from order lines.
package invoice

import "time"

// Line is one item on an invoice.
type Line struct {
	Description string `json:"description"`
	Quantity    int    `json:"quantity"`
	UnitCents   int64  `json:"unit_cents"`
}

// Invoice is what a customer is billed.
type Invoice struct {
	Number     string    `json:"number"`
	Issued     time.Time `json:"issued"`
	Lines      []Line    `json:"lines"`
	TotalCents int64     `json:"total_cents"`
}

// New builds an invoice issued at the given time.
func New(number string, issued time.Time, lines []Line) Invoice {
	var total int64
	for _, l := range lines {
		total += int64(l.Quantity) * l.UnitCents
	}
	return Invoice{Number: number, Issued: issued, Lines: lines, TotalCents: total}
}
GO
cat > invoice/invoice_test.go <<'GO'
package invoice

import (
	"testing"
	"time"
)

func TestNewTotals(t *testing.T) {
	issued := time.Date(2024, time.March, 1, 0, 0, 0, 0, time.UTC)
	inv := New("INV-1", issued, []Line{
		{Description: "Widget", Quantity: 3, UnitCents: 250},
		{Description: "Gadget", Quantity: 1, UnitCents: 1000},
	})
	if inv.TotalCents != 1750 {
		t.Fatalf("TotalCents = %d, want 1750", inv.TotalCents)
	}
}
GO
cat > README.md <<'MD'
# billing

Package `invoice` builds invoices from order lines. CI runs the tests and
golangci-lint on every push.
MD
git add -A
git commit -qm "Build invoices from order lines"
cat > invoice/invoice.go <<'GO'
// Package invoice builds invoices from order lines.
package invoice

import "time"

// paymentTermDays is how long a customer has to pay an invoice.
const paymentTermDays = 30

// Line is one item on an invoice.
type Line struct {
	Description string `json:"description"`
	Quantity    int    `json:"quantity"`
	UnitCents   int64  `json:"unit_cents"`
}

// Invoice is what a customer is billed.
type Invoice struct {
	Number     string    `json:"number"`
	Issued     time.Time `json:"issued"`
	Due        time.Time `json:"due"`
	Lines      []Line    `json:"lines"`
	TotalCents int64     `json:"total_cents"`
}

// New builds an invoice issued at the given time, due paymentTermDays later.
func New(number string, issued time.Time, lines []Line) Invoice {
	var total int64
	for _, l := range lines {
		total += int64(l.Quantity) * l.UnitCents
	}
	return Invoice{
		Number:     number,
		Issued:     issued,
		Due:        issued.AddDate(0, 0, paymentTermDays),
		Lines:      lines,
		TotalCents: total,
	}
}

// businessDaysAfter returns the date n business days after t, skipping
// Saturdays and Sundays.
func businessDaysAfter(t time.Time, n int) time.Time {
	for n > 0 {
		t = t.AddDate(0, 0, 1)
		if wd := t.Weekday(); wd != time.Saturday && wd != time.Sunday {
			n--
		}
	}
	return t
}
GO
cat > invoice/invoice_test.go <<'GO'
package invoice

import (
	"testing"
	"time"
)

func TestNewTotals(t *testing.T) {
	issued := time.Date(2024, time.March, 1, 0, 0, 0, 0, time.UTC)
	inv := New("INV-1", issued, []Line{
		{Description: "Widget", Quantity: 3, UnitCents: 250},
		{Description: "Gadget", Quantity: 1, UnitCents: 1000},
	})
	if inv.TotalCents != 1750 {
		t.Fatalf("TotalCents = %d, want 1750", inv.TotalCents)
	}
}

func TestNewDueDate(t *testing.T) {
	issued := time.Date(2024, time.March, 1, 0, 0, 0, 0, time.UTC)
	inv := New("INV-2", issued, nil)
	want := time.Date(2024, time.March, 31, 0, 0, 0, 0, time.UTC)
	if !inv.Due.Equal(want) {
		t.Fatalf("Due = %v, want %v", inv.Due, want)
	}
}
GO
