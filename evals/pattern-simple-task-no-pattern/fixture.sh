#!/bin/bash
# A small Go CLI that counts lines in the files named on the command line.
set -euo pipefail
cat > go.mod <<'GO'
module example.com/lc

go 1.22
GO
cat > main.go <<'GO'
// Command lc counts the lines in each file named on the command line.
package main

import (
	"bufio"
	"flag"
	"fmt"
	"os"
)

func main() {
	flag.Parse()
	total := 0
	for _, name := range flag.Args() {
		n, err := countLines(name)
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		total += n
	}
	fmt.Println(total)
}

func countLines(name string) (int, error) {
	f, err := os.Open(name)
	if err != nil {
		return 0, err
	}
	defer f.Close()
	n := 0
	s := bufio.NewScanner(f)
	for s.Scan() {
		n++
	}
	return n, s.Err()
}
GO
