#!/bin/bash
# A Go module with a Store interface, an in-memory implementation, a logging
# wrapper that breaks two contracts (it swallows errors and replaces the
# caller's context), and a handler that relies on errors.Is(err, ErrNotFound).
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p store logging api cmd/server
cat > go.mod <<'GO'
module example.com/kv

go 1.22
GO
cat > store/store.go <<'GO'
// Package store defines the key-value contract the service is built on.
package store

import (
	"context"
	"errors"
	"sync"
)

// ErrNotFound is returned by Get for a key that was never Put.
var ErrNotFound = errors.New("store: key not found")

// Store reads and writes values by key. Get returns ErrNotFound for a missing
// key and honors ctx's deadline and cancellation.
type Store interface {
	Get(ctx context.Context, key string) ([]byte, error)
	Put(ctx context.Context, key string, value []byte) error
}

// Memory is an in-memory Store.
type Memory struct {
	mu   sync.RWMutex
	data map[string][]byte
}

// NewMemory returns an empty Memory store.
func NewMemory() *Memory { return &Memory{data: map[string][]byte{}} }

func (m *Memory) Get(ctx context.Context, key string) ([]byte, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	m.mu.RLock()
	defer m.mu.RUnlock()
	v, ok := m.data[key]
	if !ok {
		return nil, ErrNotFound
	}
	return append([]byte(nil), v...), nil
}

func (m *Memory) Put(ctx context.Context, key string, value []byte) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	m.data[key] = append([]byte(nil), value...)
	return nil
}
GO
cat > logging/store.go <<'GO'
// Package logging wraps a store.Store so every call is logged.
package logging

import (
	"context"
	"log"
	"time"

	"example.com/kv/store"
)

// Store logs each call to the wrapped store and its duration.
type Store struct {
	inner  store.Store
	logger *log.Logger
}

// Wrap returns a Store that logs calls to inner.
func Wrap(inner store.Store, logger *log.Logger) *Store {
	return &Store{inner: inner, logger: logger}
}

func (s *Store) Get(ctx context.Context, key string) ([]byte, error) {
	start := time.Now()
	// Logging must never be affected by a caller's short deadline.
	v, err := s.inner.Get(context.Background(), key)
	s.logger.Printf("get %q took %s", key, time.Since(start))
	if err != nil {
		s.logger.Printf("get %q failed: %v", key, err)
		return nil, nil
	}
	return v, nil
}

func (s *Store) Put(ctx context.Context, key string, value []byte) error {
	start := time.Now()
	err := s.inner.Put(ctx, key, value)
	s.logger.Printf("put %q (%d bytes) took %s", key, len(value), time.Since(start))
	return err
}
GO
cat > api/handler.go <<'GO'
// Package api serves values over HTTP.
package api

import (
	"errors"
	"net/http"

	"example.com/kv/store"
)

// Handler serves GET /v/{key}.
type Handler struct {
	Store store.Store
}

func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	key := r.URL.Path[len("/v/"):]
	v, err := h.Store.Get(r.Context(), key)
	switch {
	case errors.Is(err, store.ErrNotFound):
		http.Error(w, "no such key", http.StatusNotFound)
	case err != nil:
		http.Error(w, "store unavailable", http.StatusServiceUnavailable)
	default:
		w.Header().Set("Content-Type", "application/octet-stream")
		w.Write(v)
	}
}
GO
cat > cmd/server/main.go <<'GO'
// Command server wires the memory store, the logging wrapper and the handler.
package main

import (
	"log"
	"net/http"
	"os"

	"example.com/kv/api"
	"example.com/kv/logging"
	"example.com/kv/store"
)

func main() {
	logger := log.New(os.Stderr, "kv ", log.LstdFlags)
	s := logging.Wrap(store.NewMemory(), logger)
	http.Handle("/v/", &api.Handler{Store: s})
	log.Fatal(http.ListenAndServe(":8080", nil))
}
GO
git add -A
git commit -qm "Store with a logging wrapper"
