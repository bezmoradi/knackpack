#!/bin/bash
# An ops CLI that finds each command's handler by name with reflection. The
# uncommitted change adds HandleChecksum, reached only through that lookup,
# and handleChecksumDir, an unexported method nothing can reach.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
cat > go.mod <<'GO'
module example.com/opsctl

go 1.22
GO
cat > main.go <<'GO'
// Command opsctl runs maintenance commands: opsctl <command> [args].
//
// Each command is an exported method of commands named Handle followed by
// the command's name with its first letter capitalized, so `opsctl version`
// runs HandleVersion. main finds it by name, so adding a command needs no
// registration.
package main

import (
	"fmt"
	"io"
	"os"
	"reflect"
	"strings"
)

type commands struct {
	out io.Writer
}

func main() {
	if len(os.Args) < 2 || os.Args[1] == "" {
		fmt.Fprintln(os.Stderr, "usage: opsctl <command> [args]")
		os.Exit(2)
	}
	name := os.Args[1]
	method := "Handle" + strings.ToUpper(name[:1]) + name[1:]
	m := reflect.ValueOf(commands{out: os.Stdout}).MethodByName(method)
	if !m.IsValid() {
		fmt.Fprintf(os.Stderr, "opsctl: unknown command %q\n", name)
		os.Exit(2)
	}
	run, ok := m.Interface().(func([]string) error)
	if !ok {
		fmt.Fprintf(os.Stderr, "opsctl: %s has the wrong signature\n", method)
		os.Exit(2)
	}
	if err := run(os.Args[2:]); err != nil {
		fmt.Fprintf(os.Stderr, "opsctl %s: %v\n", name, err)
		os.Exit(1)
	}
}
GO
cat > commands.go <<'GO'
package main

import (
	"fmt"
	"runtime/debug"
)

// HandleVersion prints the version opsctl was built from.
func (c commands) HandleVersion(args []string) error {
	v := "unknown"
	if info, ok := debug.ReadBuildInfo(); ok {
		v = info.Main.Version
	}
	_, err := fmt.Fprintln(c.out, v)
	return err
}
GO
cat > README.md <<'MD'
# opsctl

Maintenance commands for the platform team.

- `opsctl version` prints the version opsctl was built from.
MD
git add -A
git commit -qm "opsctl with a version command"
cat > commands.go <<'GO'
package main

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"runtime/debug"
)

// HandleVersion prints the version opsctl was built from.
func (c commands) HandleVersion(args []string) error {
	v := "unknown"
	if info, ok := debug.ReadBuildInfo(); ok {
		v = info.Main.Version
	}
	_, err := fmt.Fprintln(c.out, v)
	return err
}

// HandleChecksum prints the SHA-256 of each file named in args.
func (c commands) HandleChecksum(args []string) error {
	if len(args) == 0 {
		return errors.New("usage: opsctl checksum <file> [<file>]")
	}
	for _, name := range args {
		sum, err := fileSHA256(name)
		if err != nil {
			return err
		}
		fmt.Fprintf(c.out, "%s  %s\n", sum, name)
	}
	return nil
}

// handleChecksumDir prints the SHA-256 of every regular file under a
// directory.
func (c commands) handleChecksumDir(args []string) error {
	if len(args) != 1 {
		return errors.New("usage: opsctl checksumdir <dir>")
	}
	return filepath.WalkDir(args[0], func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if !d.Type().IsRegular() {
			return nil
		}
		sum, err := fileSHA256(path)
		if err != nil {
			return err
		}
		fmt.Fprintf(c.out, "%s  %s\n", sum, path)
		return nil
	})
}

func fileSHA256(name string) (string, error) {
	f, err := os.Open(name)
	if err != nil {
		return "", err
	}
	defer f.Close()
	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		return "", fmt.Errorf("read %s: %w", name, err)
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}
GO
cat > README.md <<'MD'
# opsctl

Maintenance commands for the platform team.

- `opsctl version` prints the version opsctl was built from.
- `opsctl checksum <file>...` prints the SHA-256 of each file.
MD
