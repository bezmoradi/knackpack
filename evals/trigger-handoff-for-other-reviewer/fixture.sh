#!/bin/bash
# A Go service with a feature branch of two commits that add a per-customer
# rate limit. The user wants a write-up to give another agent that will review
# it, not a review here and not a checkpoint.
set -euo pipefail
git init -q -b main
git config user.name "Sam Okafor"
git config user.email "sam@example.com"
cat > go.mod <<'GO'
module example.com/api

go 1.22
GO
cat > main.go <<'GO'
package main

import (
	"log"
	"net/http"
)

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /reports/{id}", getReport)
	log.Fatal(http.ListenAndServe(":8080", mux))
}

func getReport(w http.ResponseWriter, r *http.Request) {
	w.Write([]byte("report " + r.PathValue("id")))
}
GO
git add -A
git commit -qm "Reports API"
git checkout -q -b rate-limit
cat > limit.go <<'GO'
package main

import (
	"net/http"
	"sync"
	"time"
)

// limiter allows each customer n requests per window.
type limiter struct {
	mu     sync.Mutex
	n      int
	window time.Duration
	seen   map[string][]time.Time
}

func newLimiter(n int, window time.Duration) *limiter {
	return &limiter{n: n, window: window, seen: map[string][]time.Time{}}
}

func (l *limiter) allow(customer string, now time.Time) bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	var kept []time.Time
	for _, t := range l.seen[customer] {
		if now.Sub(t) < l.window {
			kept = append(kept, t)
		}
	}
	if len(kept) >= l.n {
		l.seen[customer] = kept
		return false
	}
	l.seen[customer] = append(kept, now)
	return true
}

func (l *limiter) wrap(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if !l.allow(r.Header.Get("X-Customer-ID"), time.Now()) {
			http.Error(w, "slow down", http.StatusTooManyRequests)
			return
		}
		next(w, r)
	}
}
GO
git add -A
git commit -qm "Add a per-customer sliding-window limiter"
cat > main.go <<'GO'
package main

import (
	"log"
	"net/http"
	"time"
)

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /reports/{id}", newLimiter(60, time.Minute).wrap(getReport))
	log.Fatal(http.ListenAndServe(":8080", mux))
}

func getReport(w http.ResponseWriter, r *http.Request) {
	w.Write([]byte("report " + r.PathValue("id")))
}
GO
git add -A
git commit -qm "Limit report requests to 60 a minute per customer"
