#!/bin/bash
# A small Go CLI whose -timeout flag defaults to 30 seconds. Its README and
# usage line both state that default, so changing it in main.go alone leaves
# them wrong.
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
	timeout := flag.Duration("timeout", 30*time.Second, "time allowed for the whole request, body included")
	flag.Parse()
	if flag.NArg() != 1 {
		fmt.Fprintln(os.Stderr, "usage: fetch [-timeout 30s] <url>")
		os.Exit(2)
	}

	ctx, cancel := context.WithTimeout(context.Background(), *timeout)
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

cat > README.md <<'EOF'
# fetch

Downloads a URL and prints the response body.

    fetch [-timeout 30s] <url>

`-timeout` limits the whole request, reading the body included. It defaults to 30 seconds.
EOF

git add -A
git commit -qm "fetch: download a URL"
