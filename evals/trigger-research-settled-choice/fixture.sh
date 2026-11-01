#!/bin/bash
# A small Go CLI whose -timeout flag takes whole seconds. The user has already
# decided to switch it to a duration flag, so the task is a direct edit.
set -euo pipefail
git init -q
git config user.name "Alex Morgan"
git config user.email "alex@example.com"

cat > go.mod <<'EOF'
module example.com/fetch

go 1.22
EOF

cat > main.go <<'EOF'
// Command fetch downloads a URL and prints the response body.
package main

import (
	"context"
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
	"time"
)

func main() {
	timeout := flag.Int("timeout", 30, "seconds to wait for the whole request")
	flag.Parse()
	if flag.NArg() != 1 {
		fmt.Fprintln(os.Stderr, "usage: fetch [-timeout seconds] <url>")
		os.Exit(2)
	}

	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(*timeout)*time.Second)
	defer cancel()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, flag.Arg(0), nil)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	defer resp.Body.Close()
	if _, err := io.Copy(os.Stdout, resp.Body); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
EOF

git add -A
git commit -qm "fetch: download a URL"
