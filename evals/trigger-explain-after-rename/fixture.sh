#!/bin/bash
# A small Go CLI with a -timeout flag stated in main.go, its usage line and
# the README. The user asks for a rename and then a plain-English account of
# the change for a junior colleague, which is what Explain is for.
set -euo pipefail
git init -q -b main
git config user.name "Maya Lindqvist"
git config user.email "maya@example.com"
cat > go.mod <<'GO'
module example.com/fetch

go 1.22
GO
cat > fetch.go <<'GO'
package main

import (
	"errors"
	"fmt"
	"net/http"
	"time"
)

var errGaveUp = errors.New("gave up")

// get fetches url, retrying a 5xx or a network error with doubling waits
// until deadline has passed since the first attempt.
func get(client *http.Client, url string, deadline time.Duration) (*http.Response, error) {
	start := time.Now()
	wait := 200 * time.Millisecond
	for {
		resp, err := client.Get(url)
		if err == nil && resp.StatusCode < 500 {
			return resp, nil
		}
		if err == nil {
			resp.Body.Close()
		}
		if time.Since(start)+wait > deadline {
			return nil, fmt.Errorf("%w after %s: %v", errGaveUp, time.Since(start).Round(time.Millisecond), err)
		}
		time.Sleep(wait)
		wait *= 2
	}
}
GO
cat > main.go <<'GO'
// Command fetch downloads a URL and prints the response body.
package main

import (
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
	"time"
)

func main() {
	timeout := flag.Duration("timeout", 30*time.Second, "give up after this long")
	flag.Usage = func() { fmt.Fprintln(os.Stderr, "usage: fetch [-timeout 30s] URL") }
	flag.Parse()
	if flag.NArg() != 1 {
		flag.Usage()
		os.Exit(2)
	}
	resp, err := get(http.DefaultClient, flag.Arg(0), *timeout)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	defer resp.Body.Close()
	io.Copy(os.Stdout, resp.Body)
}
GO
cat > README.md <<'MD2'
# fetch

    fetch [-timeout 30s] URL

Retries server errors and network failures with doubling waits, and gives up once `-timeout` has passed.
MD2
git add -A
git commit -qm "fetch: retry with backoff until a timeout"
