#!/bin/bash
# A Go module where two greeting formats, both known at compile time, are
# produced through a factory interface, a registry and a builder, and main.go
# picks one by a flag.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p format cmd/greet
cat > go.mod <<'GO'
module example.com/greet

go 1.22
GO
cat > format/formatter.go <<'GO'
// Package format renders greetings.
package format

import (
	"fmt"
	"strings"
)

// Formatter renders a greeting for a name.
type Formatter interface {
	Format(name string) string
}

// Factory creates a Formatter.
type Factory interface {
	Create() Formatter
}

type plain struct{}

func (plain) Format(name string) string { return fmt.Sprintf("Hello, %s.", name) }

// PlainFactory creates plain formatters.
type PlainFactory struct{}

func (PlainFactory) Create() Formatter { return plain{} }

type shout struct{}

func (shout) Format(name string) string { return strings.ToUpper(fmt.Sprintf("hello, %s!", name)) }

// ShoutFactory creates shouting formatters.
type ShoutFactory struct{}

func (ShoutFactory) Create() Formatter { return shout{} }
GO
cat > format/registry.go <<'GO'
package format

import "fmt"

// Registry maps a style name to the factory that creates it.
type Registry struct {
	factories map[string]Factory
}

// NewRegistry returns an empty Registry.
func NewRegistry() *Registry { return &Registry{factories: map[string]Factory{}} }

// Register adds a factory under name, replacing any earlier one.
func (r *Registry) Register(name string, f Factory) { r.factories[name] = f }

// Lookup returns the factory registered under name.
func (r *Registry) Lookup(name string) (Factory, error) {
	f, ok := r.factories[name]
	if !ok {
		return nil, fmt.Errorf("format: unknown style %q", name)
	}
	return f, nil
}

// DefaultRegistry holds the two built-in styles.
func DefaultRegistry() *Registry {
	r := NewRegistry()
	r.Register("plain", PlainFactory{})
	r.Register("shout", ShoutFactory{})
	return r
}
GO
cat > format/builder.go <<'GO'
package format

import "errors"

// Builder assembles a Formatter from a registry and a style name.
type Builder struct {
	registry *Registry
	style    string
}

// NewBuilder returns a Builder with no registry or style set.
func NewBuilder() *Builder { return &Builder{} }

// WithRegistry sets the registry to look styles up in.
func (b *Builder) WithRegistry(r *Registry) *Builder { b.registry = r; return b }

// WithStyle sets the style name.
func (b *Builder) WithStyle(style string) *Builder { b.style = style; return b }

// Build looks the style up and creates its Formatter.
func (b *Builder) Build() (Formatter, error) {
	if b.registry == nil {
		return nil, errors.New("format: builder has no registry")
	}
	if b.style == "" {
		return nil, errors.New("format: builder has no style")
	}
	f, err := b.registry.Lookup(b.style)
	if err != nil {
		return nil, err
	}
	return f.Create(), nil
}
GO
cat > cmd/greet/main.go <<'GO'
// Command greet prints a greeting in the plain or shout style.
package main

import (
	"flag"
	"fmt"
	"os"

	"example.com/greet/format"
)

func main() {
	style := flag.String("style", "plain", "plain or shout")
	name := flag.String("name", "world", "whom to greet")
	flag.Parse()

	f, err := format.NewBuilder().
		WithRegistry(format.DefaultRegistry()).
		WithStyle(*style).
		Build()
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}
	fmt.Println(f.Format(*name))
}
GO
git add -A
git commit -qm "Greeting formats behind a factory, registry and builder"
