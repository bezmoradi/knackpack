#!/bin/bash
# A Go module where a scheduler decides what is due against an injected clock.
# The only production implementation wraps time.Now; the tests inject a fake
# so they can move time without sleeping.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p schedule
cat > go.mod <<'GO'
module example.com/jobs

go 1.22
GO
cat > schedule/scheduler.go <<'GO'
// Package schedule decides which jobs are due.
package schedule

import "time"

// Clock is the time source the Scheduler reads. Production uses the real
// clock; tests inject a fake so they can move time without sleeping.
type Clock interface {
	Now() time.Time
}

type realClock struct{}

func (realClock) Now() time.Time { return time.Now() }

// RealClock returns a Clock backed by time.Now.
func RealClock() Clock { return realClock{} }

// Job runs at a fixed time and then every Interval.
type Job struct {
	Name     string
	FirstRun time.Time
	Interval time.Duration
}

// Scheduler reports which jobs are due at the clock's current time.
type Scheduler struct {
	clock Clock
	jobs  []Job
	last  map[string]time.Time
}

// New returns a Scheduler reading time from clock.
func New(clock Clock) *Scheduler {
	return &Scheduler{clock: clock, last: map[string]time.Time{}}
}

// Add registers a job.
func (s *Scheduler) Add(j Job) { s.jobs = append(s.jobs, j) }

// Due returns the names of jobs that should run now and marks them as run.
func (s *Scheduler) Due() []string {
	now := s.clock.Now()
	var due []string
	for _, j := range s.jobs {
		last, ran := s.last[j.Name]
		switch {
		case !ran && !now.Before(j.FirstRun):
			due = append(due, j.Name)
		case ran && now.Sub(last) >= j.Interval:
			due = append(due, j.Name)
		default:
			continue
		}
		s.last[j.Name] = now
	}
	return due
}
GO
cat > schedule/scheduler_test.go <<'GO'
package schedule

import (
	"testing"
	"time"
)

// fakeClock stands still until the test advances it.
type fakeClock struct{ now time.Time }

func (f *fakeClock) Now() time.Time          { return f.now }
func (f *fakeClock) Advance(d time.Duration) { f.now = f.now.Add(d) }

func TestDueRunsOnFirstRunThenEveryInterval(t *testing.T) {
	start := time.Date(2026, 1, 1, 9, 0, 0, 0, time.UTC)
	clock := &fakeClock{now: start}
	s := New(clock)
	s.Add(Job{Name: "report", FirstRun: start.Add(time.Hour), Interval: 24 * time.Hour})

	if got := s.Due(); len(got) != 0 {
		t.Fatalf("due before first run: %v", got)
	}
	clock.Advance(time.Hour)
	if got := s.Due(); len(got) != 1 || got[0] != "report" {
		t.Fatalf("due at first run: %v", got)
	}
	clock.Advance(23 * time.Hour)
	if got := s.Due(); len(got) != 0 {
		t.Fatalf("due before the interval passed: %v", got)
	}
	clock.Advance(time.Hour)
	if got := s.Due(); len(got) != 1 {
		t.Fatalf("due after the interval: %v", got)
	}
}
GO
git add -A
git commit -qm "Scheduler with an injected clock"
