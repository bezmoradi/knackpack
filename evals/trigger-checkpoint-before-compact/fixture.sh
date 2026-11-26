#!/bin/bash
# A Go service halfway through moving its invoice export onto a job queue:
# the producer is committed, the consumer is uncommitted and unfinished. The
# user is about to compact and wants the state saved, which is a checkpoint,
# not a handoff to a reviewer.
set -euo pipefail
git init -q -b main
git config user.name "Sam Okafor"
git config user.email "sam@example.com"
cat > go.mod <<'GO'
module example.com/invoices

go 1.22
GO
cat > queue.go <<'GO'
package main

// Job is one unit of work on the export queue.
type Job struct {
	InvoiceID string
	Attempt   int
}

// Queue is the in-process export queue.
type Queue struct{ jobs chan Job }

func NewQueue(size int) *Queue { return &Queue{jobs: make(chan Job, size)} }

func (q *Queue) Push(j Job) { q.jobs <- j }
GO
cat > export.go <<'GO'
package main

import "net/http"

// exportInvoice queues the invoice for export instead of exporting inline.
func exportInvoice(q *Queue) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		q.Push(Job{InvoiceID: r.PathValue("id")})
		w.WriteHeader(http.StatusAccepted)
	}
}
GO
git add -A
git commit -qm "Queue invoice exports instead of exporting inline"
cat > worker.go <<'GO'
package main

import "log"

// runWorker drains the export queue.
func runWorker(q *Queue, export func(id string) error) {
	for j := range q.jobs {
		if err := export(j.InvoiceID); err != nil {
			// TODO: retry with backoff, up to 5 attempts, then dead-letter.
			log.Printf("export %s: %v", j.InvoiceID, err)
		}
	}
}
GO
