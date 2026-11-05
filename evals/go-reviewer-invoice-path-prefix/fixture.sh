#!/bin/bash
# A billing service that keeps each organization's invoice PDFs under
# <root>/<org slug>/, plus an uncommitted download endpoint whose path guard is
# a plain HasPrefix on the cleaned path.
set -euo pipefail
git init -q
git config user.name "Sam Rivera"
git config user.email "sam@example.com"
mkdir -p internal/auth internal/invoices cmd/billing
cat > go.mod <<'GO'
module example.com/billing

go 1.24
GO
cat > README.md <<'MD'
# billing

Serves invoices to signed-in customers. Each organization's invoice PDFs are
stored under `$INVOICE_ROOT/<org slug>/`, for example
`/data/invoices/acme/2026-10.pdf`. Org slugs are lowercase letters, digits and
hyphens, chosen by the customer at sign-up.
MD
cat > internal/auth/auth.go <<'GO'
// Package auth resolves the caller's organization from the verified session.
package auth

import (
	"context"
	"net/http"
)

type ctxKey struct{}

// WithOrg returns ctx carrying the caller's organization slug.
func WithOrg(ctx context.Context, slug string) context.Context {
	return context.WithValue(ctx, ctxKey{}, slug)
}

// Org returns the caller's organization slug, set by Middleware after the
// session was verified.
func Org(ctx context.Context) (string, bool) {
	s, ok := ctx.Value(ctxKey{}).(string)
	return s, ok && s != ""
}

// Middleware verifies the session cookie and stores the caller's org slug.
func Middleware(verify func(*http.Request) (string, error), next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		slug, err := verify(r)
		if err != nil {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}
		next.ServeHTTP(w, r.WithContext(WithOrg(r.Context(), slug)))
	})
}
GO
cat > internal/invoices/list.go <<'GO'
// Package invoices serves an organization's invoice files.
package invoices

import (
	"encoding/json"
	"net/http"
	"os"
	"path/filepath"

	"example.com/billing/internal/auth"
)

// Handler serves the signed-in organization's invoices from Root.
type Handler struct {
	Root string
}

// List returns the names of the caller's invoice files.
func (h *Handler) List(w http.ResponseWriter, r *http.Request) {
	org, ok := auth.Org(r.Context())
	if !ok {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}
	entries, err := os.ReadDir(filepath.Join(h.Root, org))
	if err != nil && !os.IsNotExist(err) {
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	names := make([]string, 0, len(entries))
	for _, e := range entries {
		if !e.IsDir() {
			names = append(names, e.Name())
		}
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(names)
}
GO
cat > cmd/billing/main.go <<'GO'
// Command billing serves customers' invoices.
package main

import (
	"errors"
	"log"
	"net/http"
	"os"
	"time"

	"example.com/billing/internal/auth"
	"example.com/billing/internal/invoices"
)

// verifySession stands in for the real session check.
func verifySession(r *http.Request) (string, error) {
	c, err := r.Cookie("session")
	if err != nil || c.Value == "" {
		return "", errors.New("no session")
	}
	return "acme", nil
}

func main() {
	h := &invoices.Handler{Root: os.Getenv("INVOICE_ROOT")}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /invoices", h.List)
	srv := &http.Server{
		Addr:              ":8080",
		Handler:           auth.Middleware(verifySession, mux),
		ReadHeaderTimeout: 5 * time.Second,
	}
	log.Fatal(srv.ListenAndServe())
}
GO
git add -A
git commit -qm "List an organization's invoices"
cat > internal/invoices/download.go <<'GO'
package invoices

import (
	"net/http"
	"path/filepath"
	"strings"

	"example.com/billing/internal/auth"
)

// Download serves one of the caller's invoice files, named by ?name=.
func (h *Handler) Download(w http.ResponseWriter, r *http.Request) {
	org, ok := auth.Org(r.Context())
	if !ok {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}
	name := r.URL.Query().Get("name")
	if name == "" {
		http.Error(w, "name is required", http.StatusBadRequest)
		return
	}
	base := filepath.Join(h.Root, org)
	p := filepath.Clean(filepath.Join(base, name))
	// Never serve anything outside the caller's own folder.
	if !strings.HasPrefix(p, base) {
		http.Error(w, "forbidden", http.StatusForbidden)
		return
	}
	w.Header().Set("Content-Type", "application/pdf")
	http.ServeFile(w, r, p)
}
GO
cat > cmd/billing/main.go <<'GO'
// Command billing serves customers' invoices.
package main

import (
	"errors"
	"log"
	"net/http"
	"os"
	"time"

	"example.com/billing/internal/auth"
	"example.com/billing/internal/invoices"
)

// verifySession stands in for the real session check.
func verifySession(r *http.Request) (string, error) {
	c, err := r.Cookie("session")
	if err != nil || c.Value == "" {
		return "", errors.New("no session")
	}
	return "acme", nil
}

func main() {
	h := &invoices.Handler{Root: os.Getenv("INVOICE_ROOT")}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /invoices", h.List)
	mux.HandleFunc("GET /invoices/download", h.Download)
	srv := &http.Server{
		Addr:              ":8080",
		Handler:           auth.Middleware(verifySession, mux),
		ReadHeaderTimeout: 5 * time.Second,
	}
	log.Fatal(srv.ListenAndServe())
}
GO
