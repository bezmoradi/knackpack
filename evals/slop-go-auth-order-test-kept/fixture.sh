#!/bin/bash
# A document vault. The uncommitted change adds Service.Save, which checks
# permission before writing, with tests that assert the order of those calls,
# as a decision record in the repository requires.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p files docs/decisions
cat > go.mod <<'GO'
module example.com/vault

go 1.22
GO
cat > files/files.go <<'GO'
// Package files stores users' documents.
package files

import (
	"context"
	"errors"
)

// Document is one stored document.
type Document struct {
	ID     string
	Folder string
	Body   []byte
}

// ErrForbidden means the user may not write to the folder.
var ErrForbidden = errors.New("forbidden")

// Authorizer decides who may write where.
type Authorizer interface {
	CanWrite(ctx context.Context, user, folder string) error
}

// Store keeps documents.
type Store interface {
	Put(ctx context.Context, d Document) error
}
GO
cat > files/roles.go <<'GO'
package files

import (
	"context"
	"slices"
)

// Roles is an Authorizer that lists the folders each user may write to.
type Roles map[string][]string

// CanWrite returns ErrForbidden unless user may write to folder.
func (r Roles) CanWrite(ctx context.Context, user, folder string) error {
	if slices.Contains(r[user], folder) {
		return nil
	}
	return ErrForbidden
}
GO
cat > files/memstore.go <<'GO'
package files

import (
	"context"
	"sync"
)

// MemStore is a Store kept in memory, for the demo server.
type MemStore struct {
	mu   sync.Mutex
	docs map[string]Document
}

// Put stores d, replacing any document with the same ID.
func (m *MemStore) Put(ctx context.Context, d Document) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.docs == nil {
		m.docs = make(map[string]Document)
	}
	m.docs[d.ID] = d
	return nil
}
GO
cat > docs/decisions/0004-authorize-before-write.md <<'MD'
# 4. Authorize before every write

## Status

Accepted

## Context

Every write is copied to the compliance archive within seconds, and the
archive can't be edited. A write that lands before a failed permission check
leaks the document into the archive for good.

## Decision

Every write path checks the caller's permission before it touches storage,
and has a test that records the calls it makes and asserts that the check
comes first and that a denied check writes nothing.
MD
git add -A
git commit -qm "Document types, roles and the authorize-before-write decision"
cat > files/service.go <<'GO'
package files

import (
	"context"
	"fmt"
)

// Service saves documents for signed-in users.
type Service struct {
	authz Authorizer
	store Store
}

// NewService returns a Service that checks permissions with authz and
// writes to store.
func NewService(authz Authorizer, store Store) *Service {
	return &Service{authz: authz, store: store}
}

// Save writes d after checking that user may write to d's folder.
func (s *Service) Save(ctx context.Context, user string, d Document) error {
	if err := s.authz.CanWrite(ctx, user, d.Folder); err != nil {
		return fmt.Errorf("save %s: %w", d.ID, err)
	}
	if err := s.store.Put(ctx, d); err != nil {
		return fmt.Errorf("save %s: %w", d.ID, err)
	}
	return nil
}
GO
cat > files/service_test.go <<'GO'
package files

import (
	"context"
	"errors"
	"slices"
	"testing"
)

type recorder struct {
	calls []string
}

type fakeAuthz struct {
	rec  *recorder
	deny bool
}

func (f fakeAuthz) CanWrite(ctx context.Context, user, folder string) error {
	f.rec.calls = append(f.rec.calls, "CanWrite")
	if f.deny {
		return ErrForbidden
	}
	return nil
}

type fakeStore struct {
	rec *recorder
}

func (f fakeStore) Put(ctx context.Context, d Document) error {
	f.rec.calls = append(f.rec.calls, "Put")
	return nil
}

func TestSaveChecksPermissionBeforeWriting(t *testing.T) {
	rec := &recorder{}
	s := NewService(fakeAuthz{rec: rec}, fakeStore{rec: rec})
	if err := s.Save(context.Background(), "ana", Document{ID: "d1", Folder: "hr"}); err != nil {
		t.Fatal(err)
	}
	if want := []string{"CanWrite", "Put"}; !slices.Equal(rec.calls, want) {
		t.Fatalf("calls = %v, want %v", rec.calls, want)
	}
}

func TestSaveWritesNothingWhenDenied(t *testing.T) {
	rec := &recorder{}
	s := NewService(fakeAuthz{rec: rec, deny: true}, fakeStore{rec: rec})
	err := s.Save(context.Background(), "ana", Document{ID: "d1", Folder: "hr"})
	if !errors.Is(err, ErrForbidden) {
		t.Fatalf("err = %v, want ErrForbidden", err)
	}
	if want := []string{"CanWrite"}; !slices.Equal(rec.calls, want) {
		t.Fatalf("calls = %v, want %v", rec.calls, want)
	}
}
GO
