#!/bin/bash
# A Go module with an in-process event bus: synchronous delivery to callbacks
# in subscription order, a copied handler list so handlers may unsubscribe
# while a publish is in progress, and an unsubscribe closure.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p events cmd/demo
cat > go.mod <<'GO'
module example.com/bus

go 1.22
GO
cat > events/bus.go <<'GO'
// Package events delivers in-process events to subscribers.
//
// Delivery is synchronous: Publish calls every handler on the publisher's
// goroutine, in subscription order, and returns when the last one returns.
// Handlers that need to do slow work start their own goroutine. A handler may
// subscribe or unsubscribe during a publish; it takes effect for the next one.
package events

import "sync"

// Event is what subscribers receive.
type Event struct {
	Topic   string
	Payload any
}

// Handler receives one event.
type Handler func(Event)

// Bus fans events out to handlers by topic.
type Bus struct {
	mu       sync.Mutex
	next     int
	handlers map[string]map[int]Handler
}

// New returns an empty Bus.
func New() *Bus { return &Bus{handlers: map[string]map[int]Handler{}} }

// Subscribe registers h for topic and returns the function that removes it.
// Calling the returned function more than once is harmless.
func (b *Bus) Subscribe(topic string, h Handler) (unsubscribe func()) {
	b.mu.Lock()
	defer b.mu.Unlock()
	id := b.next
	b.next++
	if b.handlers[topic] == nil {
		b.handlers[topic] = map[int]Handler{}
	}
	b.handlers[topic][id] = h
	return func() {
		b.mu.Lock()
		defer b.mu.Unlock()
		delete(b.handlers[topic], id)
	}
}

// Publish delivers e to every handler subscribed to its topic, in the order
// they subscribed, and returns once all have returned.
func (b *Bus) Publish(e Event) {
	b.mu.Lock()
	ids := make([]int, 0, len(b.handlers[e.Topic]))
	for id := range b.handlers[e.Topic] {
		ids = append(ids, id)
	}
	sortInts(ids)
	hs := make([]Handler, 0, len(ids))
	for _, id := range ids {
		hs = append(hs, b.handlers[e.Topic][id])
	}
	b.mu.Unlock()
	for _, h := range hs {
		h(e)
	}
}

func sortInts(a []int) {
	for i := 1; i < len(a); i++ {
		for j := i; j > 0 && a[j-1] > a[j]; j-- {
			a[j-1], a[j] = a[j], a[j-1]
		}
	}
}
GO
cat > cmd/demo/main.go <<'GO'
// Command demo publishes two events and shows one subscriber leaving between them.
package main

import (
	"fmt"

	"example.com/bus/events"
)

func main() {
	bus := events.New()
	bus.Subscribe("order.paid", func(e events.Event) { fmt.Println("ledger:", e.Payload) })
	stop := bus.Subscribe("order.paid", func(e events.Event) { fmt.Println("email:", e.Payload) })
	bus.Publish(events.Event{Topic: "order.paid", Payload: "order 1"})
	stop()
	bus.Publish(events.Event{Topic: "order.paid", Payload: "order 2"})
}
GO
git add -A
git commit -qm "Synchronous callback event bus"
