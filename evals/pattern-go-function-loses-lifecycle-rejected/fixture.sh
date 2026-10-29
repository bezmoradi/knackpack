#!/bin/bash
# A Go module with a token-bucket limiter: tokens behind a mutex, refilled by
# a goroutine on a ticker, with Stop ending the goroutine. Callers hold the
# limiter for the life of the server.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p ratelimit cmd/api
cat > go.mod <<'GO'
module example.com/api

go 1.22
GO
cat > ratelimit/limiter.go <<'GO'
// Package ratelimit admits a bounded number of operations per interval.
package ratelimit

import (
	"sync"
	"time"
)

// Limiter is a token bucket. Allow takes a token when one is available, and a
// background goroutine puts refill tokens back every interval, up to capacity.
type Limiter struct {
	mu       sync.Mutex
	tokens   int
	capacity int
	refill   int
	stop     chan struct{}
	done     chan struct{}
}

// New starts a limiter with capacity tokens that regains refill tokens every
// interval. Call Stop when the limiter is no longer needed.
func New(capacity, refill int, interval time.Duration) *Limiter {
	l := &Limiter{
		tokens:   capacity,
		capacity: capacity,
		refill:   refill,
		stop:     make(chan struct{}),
		done:     make(chan struct{}),
	}
	go l.run(interval)
	return l
}

func (l *Limiter) run(interval time.Duration) {
	defer close(l.done)
	t := time.NewTicker(interval)
	defer t.Stop()
	for {
		select {
		case <-t.C:
			l.mu.Lock()
			l.tokens += l.refill
			if l.tokens > l.capacity {
				l.tokens = l.capacity
			}
			l.mu.Unlock()
		case <-l.stop:
			return
		}
	}
}

// Allow reports whether one more operation may proceed now.
func (l *Limiter) Allow() bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	if l.tokens == 0 {
		return false
	}
	l.tokens--
	return true
}

// Stop ends the refill goroutine and waits for it to exit. It is safe to call
// once; Allow keeps working afterwards but no tokens come back.
func (l *Limiter) Stop() {
	close(l.stop)
	<-l.done
}
GO
cat > cmd/api/main.go <<'GO'
// Command api serves one endpoint behind a per-process rate limit.
package main

import (
	"log"
	"net/http"
	"time"

	"example.com/api/ratelimit"
)

func main() {
	limiter := ratelimit.New(100, 10, time.Second)
	defer limiter.Stop()

	http.HandleFunc("/ping", func(w http.ResponseWriter, r *http.Request) {
		if !limiter.Allow() {
			http.Error(w, "slow down", http.StatusTooManyRequests)
			return
		}
		w.Write([]byte("pong\n"))
	})
	log.Fatal(http.ListenAndServe(":8080", nil))
}
GO
git add -A
git commit -qm "Token-bucket limiter"
