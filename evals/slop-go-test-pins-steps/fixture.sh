#!/bin/bash
# A bookmarks service. The uncommitted change adds a tag normalizer whose
# tests assert the order of its internal steps through a trace hook and never
# check the normalized tags.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p tags
cat > go.mod <<'GO'
module example.com/bookmarks

go 1.22
GO
cat > tags/doc.go <<'GO'
// Package tags handles the labels users attach to bookmarks.
package tags
GO
cat > README.md <<'MD'
# bookmarks

Saves bookmarks with the tags users give them.
MD
git add -A
git commit -qm "Bookmarks skeleton"
cat > tags/normalize.go <<'GO'
package tags

import "strings"

// Normalizer cleans up the tags users type: it trims spaces, lowercases, and
// drops empty and repeated tags, keeping the first of each.
type Normalizer struct {
	// trace, when set, is told the name of each step as it runs.
	trace func(step string)
}

// Normalize returns the cleaned-up tags in their original order.
func (n Normalizer) Normalize(tags []string) []string {
	out := make([]string, 0, len(tags))
	seen := make(map[string]bool, len(tags))
	for _, t := range tags {
		n.step("trim")
		t = strings.TrimSpace(t)
		n.step("lower")
		t = strings.ToLower(t)
		if t == "" || seen[t] {
			continue
		}
		n.step("dedupe")
		seen[t] = true
		out = append(out, t)
	}
	return out
}

func (n Normalizer) step(name string) {
	if n.trace != nil {
		n.trace(name)
	}
}
GO
cat > tags/normalize_test.go <<'GO'
package tags

import (
	"slices"
	"testing"
)

func TestNormalizeRunsStepsInOrder(t *testing.T) {
	var steps []string
	n := Normalizer{trace: func(s string) { steps = append(steps, s) }}
	n.Normalize([]string{"  Go "})
	want := []string{"trim", "lower", "dedupe"}
	if !slices.Equal(steps, want) {
		t.Fatalf("steps = %v, want %v", steps, want)
	}
}

func TestNormalizeSkipsDedupeForRepeats(t *testing.T) {
	var steps []string
	n := Normalizer{trace: func(s string) { steps = append(steps, s) }}
	n.Normalize([]string{"go", "Go"})
	want := []string{"trim", "lower", "dedupe", "trim", "lower"}
	if !slices.Equal(steps, want) {
		t.Fatalf("steps = %v, want %v", steps, want)
	}
}
GO
