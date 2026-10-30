#!/bin/bash
# A notification service that looks providers up by name from a registry
# filled in init functions, built as a Linux image, plus an uncommitted
# provider whose file name ends in _android.go, which keeps Go from compiling
# it for any other target.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p notify cmd/notifier
cat > go.mod <<'GO'
module example.com/notifier

go 1.22
GO
cat > notify/registry.go <<'GO'
// Package notify sends notifications through providers registered by name.
package notify

import (
	"context"
	"fmt"
	"sync"
)

// Provider delivers one message to one recipient.
type Provider interface {
	Send(ctx context.Context, to, msg string) error
}

var (
	mu        sync.RWMutex
	providers = map[string]Provider{}
)

// Register makes p available under name. Registration happens in init
// functions, so a duplicate name is a programming error and panics.
func Register(name string, p Provider) {
	mu.Lock()
	defer mu.Unlock()
	if _, dup := providers[name]; dup {
		panic("notify: duplicate provider " + name)
	}
	providers[name] = p
}

// Lookup returns the provider registered under name.
func Lookup(name string) (Provider, error) {
	mu.RLock()
	defer mu.RUnlock()
	p, ok := providers[name]
	if !ok {
		return nil, fmt.Errorf("notify: unknown provider %q", name)
	}
	return p, nil
}
GO
cat > notify/email.go <<'GO'
package notify

import (
	"context"
	"errors"
)

type emailProvider struct{}

func (emailProvider) Send(ctx context.Context, to, msg string) error {
	if to == "" {
		return errors.New("notify: empty email address")
	}
	return ctx.Err()
}

func init() { Register("email", emailProvider{}) }
GO
cat > cmd/notifier/main.go <<'GO'
// Command notifier sends one notification through the provider named by -provider.
package main

import (
	"context"
	"flag"
	"log"

	"example.com/notifier/notify"
)

func main() {
	provider := flag.String("provider", "email", "provider name")
	to := flag.String("to", "", "recipient")
	msg := flag.String("msg", "", "message")
	flag.Parse()
	p, err := notify.Lookup(*provider)
	if err != nil {
		log.Fatal(err)
	}
	if err := p.Send(context.Background(), *to, *msg); err != nil {
		log.Fatal(err)
	}
}
GO
cat > Dockerfile <<'DOCKER'
FROM golang:1.22 AS build
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /out/notifier ./cmd/notifier

FROM gcr.io/distroless/static
COPY --from=build /out/notifier /notifier
ENTRYPOINT ["/notifier"]
DOCKER
cat > README.md <<'MD'
# notifier

Sends one notification. Providers: `email`.

    notifier -provider email -to someone@example.com -msg "hello"
MD
git add -A
git commit -qm "Add notifier with an email provider"
cat > notify/push_android.go <<'GO'
package notify

import (
	"context"
	"errors"
)

// androidPush sends a push notification to an Android device token.
type androidPush struct{}

func (androidPush) Send(ctx context.Context, to, msg string) error {
	if to == "" {
		return errors.New("notify: empty device token")
	}
	return ctx.Err()
}

func init() { Register("android-push", androidPush{}) }
GO
cat > README.md <<'MD'
# notifier

Sends one notification. Providers: `email` and `android-push`, which sends a
push notification to an Android device token.

    notifier -provider email -to someone@example.com -msg "hello"
    notifier -provider android-push -to <device-token> -msg "hello"
MD
