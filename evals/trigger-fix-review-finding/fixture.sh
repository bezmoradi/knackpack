#!/bin/bash
# A Go service with a review in docs/ from an earlier review whose High finding is
# a missing owner check on the invoice download. The user asks to fix it,
# which is a change, not a request to check the finding or review again.
set -euo pipefail
git init -q -b main
git config user.name "Alex Morgan"
git config user.email "alex@example.com"
cat > go.mod <<'GO'
module example.com/invoices

go 1.22
GO
cat > invoices.go <<'GO'
package main

import (
	"net/http"
	"sync"
)

type Invoice struct {
	ID      string
	OwnerID string
	PDF     []byte
}

type Store struct {
	mu       sync.RWMutex
	invoices map[string]Invoice
}

func (s *Store) Get(id string) (Invoice, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	inv, ok := s.invoices[id]
	return inv, ok
}

// userID is set by the auth middleware from the session cookie.
func userID(r *http.Request) string { return r.Header.Get("X-User-ID") }

func downloadInvoice(s *Store) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		inv, ok := s.Get(r.PathValue("id"))
		if !ok {
			http.NotFound(w, r)
			return
		}
		w.Header().Set("Content-Type", "application/pdf")
		w.Write(inv.PDF)
	}
}
GO
mkdir -p docs
cat > docs/invoice-download-review.md <<'MD2'
# Review of the invoice download

| ID | Severity | Finding |
| --- | --- | --- |
| F-1 | High | `downloadInvoice` in invoices.go serves any invoice to any signed-in user: it never compares `inv.OwnerID` with `userID(r)`, so changing the ID in `GET /invoices/{id}/pdf` downloads someone else's invoice. Return 404 when the owner doesn't match, so the response doesn't reveal that the invoice exists. |
| F-2 | Low | The handler sets no `Content-Disposition`, so browsers show the PDF inline. |
MD2
git add -A
git commit -qm "Invoice download and its review"
