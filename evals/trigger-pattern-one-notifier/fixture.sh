#!/bin/bash
# A Go service with a Notifier interface that only EmailNotifier implements.
# The user asks whether that one interface earns its keep, which is the
# design pattern reviewer's question, not a slop check of a whole change or
# an architecture review.
set -euo pipefail
git init -q -b main
git config user.name "Tomás Ruiz"
git config user.email "tomas@example.com"
cat > go.mod <<'GO'
module example.com/alerts

go 1.22
GO
cat > notify.go <<'GO'
package main

import (
	"fmt"
	"net/smtp"
)

// Notifier sends a message to a person.
type Notifier interface {
	Notify(to, subject, body string) error
}

// EmailNotifier sends notifications by email.
type EmailNotifier struct {
	Addr string
	From string
}

func (e EmailNotifier) Notify(to, subject, body string) error {
	msg := fmt.Sprintf("From: %s\r\nTo: %s\r\nSubject: %s\r\n\r\n%s", e.From, to, subject, body)
	return smtp.SendMail(e.Addr, nil, e.From, []string{to}, []byte(msg))
}
GO
cat > alerts.go <<'GO'
package main

import "fmt"

type Alerter struct {
	n Notifier
}

func (a Alerter) DiskFull(owner string, pct int) error {
	return a.n.Notify(owner, "Disk almost full", fmt.Sprintf("Your volume is %d%% full.", pct))
}

func main() {
	a := Alerter{n: EmailNotifier{Addr: "localhost:25", From: "alerts@example.com"}}
	_ = a.DiskFull("ops@example.com", 93)
}
GO
git add -A
git commit -qm "Disk alerts by email"
