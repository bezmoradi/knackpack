#!/bin/bash
# A Go CLI that prunes old backup archives. The task was one flag, -dry-run,
# that lists what prune would delete without deleting it. The uncommitted
# change adds the flag, and also renames the package internal/store to
# internal/archive, splits its one file in three, renames every exported
# function and its callers, and rewrites the README, so the flag is a few
# lines in a diff of about 300. The behavior is otherwise unchanged and
# the tests pass.
set -euo pipefail
git init -q
git config user.name "Tomas Lindqvist"
git config user.email "tomas@example.com"

cat > go.mod <<'GO'
module example.com/backupctl

go 1.22
GO

cat > README.md <<'EOF'
# backupctl

Housekeeping for the nightly database backups.

    backupctl prune -dir /var/backups/db -keep-days 30

deletes every `.tar.gz` archive in the folder older than the given number of
days.
EOF

mkdir -p cmd/backupctl internal/store
cat > cmd/backupctl/main.go <<'GO'
package main

import (
	"flag"
	"fmt"
	"os"
	"time"

	"example.com/backupctl/internal/store"
)

func main() {
	if len(os.Args) < 2 || os.Args[1] != "prune" {
		fmt.Fprintln(os.Stderr, "usage: backupctl prune -dir <folder> [-keep-days N]")
		os.Exit(2)
	}
	fs := flag.NewFlagSet("prune", flag.ExitOnError)
	dir := fs.String("dir", "", "folder holding the archives")
	keepDays := fs.Int("keep-days", 30, "keep archives newer than this many days")
	fs.Parse(os.Args[2:])
	if *dir == "" {
		fmt.Fprintln(os.Stderr, "prune: -dir is required")
		os.Exit(2)
	}
	cutoff := time.Now().AddDate(0, 0, -*keepDays)
	removed, err := store.Prune(*dir, cutoff)
	if err != nil {
		fmt.Fprintln(os.Stderr, "prune:", err)
		os.Exit(1)
	}
	for _, name := range removed {
		fmt.Println("removed", name)
	}
}
GO

cat > internal/store/store.go <<'GO'
// Package store finds and deletes backup archives in a folder.
package store

import (
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

// Archive is one backup file.
type Archive struct {
	Name    string
	ModTime time.Time
}

// List returns the folder's .tar.gz archives, oldest first.
func List(dir string) ([]Archive, error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, err
	}
	var out []Archive
	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".tar.gz") {
			continue
		}
		info, err := e.Info()
		if err != nil {
			return nil, err
		}
		out = append(out, Archive{Name: e.Name(), ModTime: info.ModTime()})
	}
	sort.Slice(out, func(i, j int) bool { return out[i].ModTime.Before(out[j].ModTime) })
	return out, nil
}

// Prune deletes the archives older than cutoff and returns their names.
func Prune(dir string, cutoff time.Time) ([]string, error) {
	archives, err := List(dir)
	if err != nil {
		return nil, err
	}
	var removed []string
	for _, a := range archives {
		if !a.ModTime.Before(cutoff) {
			continue
		}
		if err := os.Remove(filepath.Join(dir, a.Name)); err != nil {
			return removed, err
		}
		removed = append(removed, a.Name)
	}
	return removed, nil
}
GO

cat > internal/store/store_test.go <<'GO'
package store

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func write(t *testing.T, dir, name string, age time.Duration) {
	t.Helper()
	p := filepath.Join(dir, name)
	if err := os.WriteFile(p, []byte("x"), 0o600); err != nil {
		t.Fatal(err)
	}
	when := time.Now().Add(-age)
	if err := os.Chtimes(p, when, when); err != nil {
		t.Fatal(err)
	}
}

func TestPruneDeletesOnlyOldArchives(t *testing.T) {
	dir := t.TempDir()
	write(t, dir, "old.tar.gz", 40*24*time.Hour)
	write(t, dir, "new.tar.gz", 2*24*time.Hour)
	write(t, dir, "notes.txt", 90*24*time.Hour)
	removed, err := Prune(dir, time.Now().AddDate(0, 0, -30))
	if err != nil {
		t.Fatal(err)
	}
	if len(removed) != 1 || removed[0] != "old.tar.gz" {
		t.Fatalf("removed %v, want [old.tar.gz]", removed)
	}
	if _, err := os.Stat(filepath.Join(dir, "new.tar.gz")); err != nil {
		t.Fatal("new.tar.gz was deleted")
	}
}
GO

git add -A
git commit -qm "backupctl: prune old backup archives"

# The uncommitted change: the -dry-run flag, inside a package rename, a file
# split and renamed functions.
rm -r internal/store
mkdir -p internal/archive

cat > internal/archive/doc.go <<'GO'
// Package archive discovers and removes the backup archives kept in a
// backup folder.
//
// An archive is any regular file whose name ends in .tar.gz. Archives are
// ordered by modification time, oldest first.
package archive
GO

cat > internal/archive/discover.go <<'GO'
package archive

import (
	"os"
	"sort"
	"strings"
	"time"
)

// Entry describes one backup archive found in a folder.
type Entry struct {
	// FileName is the archive's name within the folder.
	FileName string
	// Modified is the archive's modification time.
	Modified time.Time
}

// archiveSuffix is the file name suffix that marks a backup archive.
const archiveSuffix = ".tar.gz"

// Discover returns the archives in folder, ordered oldest first.
func Discover(folder string) ([]Entry, error) {
	dirEntries, err := os.ReadDir(folder)
	if err != nil {
		return nil, err
	}
	var entries []Entry
	for _, dirEntry := range dirEntries {
		if dirEntry.IsDir() || !strings.HasSuffix(dirEntry.Name(), archiveSuffix) {
			continue
		}
		fileInfo, err := dirEntry.Info()
		if err != nil {
			return nil, err
		}
		entries = append(entries, Entry{FileName: dirEntry.Name(), Modified: fileInfo.ModTime()})
	}
	sort.Slice(entries, func(i, j int) bool { return entries[i].Modified.Before(entries[j].Modified) })
	return entries, nil
}
GO

cat > internal/archive/remove.go <<'GO'
package archive

import (
	"os"
	"path/filepath"
	"time"
)

// RemoveOlderThan removes the archives in folder modified before cutoff and
// returns their names. With dryRun set it removes nothing and returns the
// names it would have removed.
func RemoveOlderThan(folder string, cutoff time.Time, dryRun bool) ([]string, error) {
	entries, err := Discover(folder)
	if err != nil {
		return nil, err
	}
	var names []string
	for _, entry := range entries {
		if !entry.Modified.Before(cutoff) {
			continue
		}
		if !dryRun {
			if err := os.Remove(filepath.Join(folder, entry.FileName)); err != nil {
				return names, err
			}
		}
		names = append(names, entry.FileName)
	}
	return names, nil
}
GO

cat > internal/archive/remove_test.go <<'GO'
package archive

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func writeArchive(t *testing.T, folder, fileName string, age time.Duration) {
	t.Helper()
	path := filepath.Join(folder, fileName)
	if err := os.WriteFile(path, []byte("x"), 0o600); err != nil {
		t.Fatal(err)
	}
	modified := time.Now().Add(-age)
	if err := os.Chtimes(path, modified, modified); err != nil {
		t.Fatal(err)
	}
}

func TestRemoveOlderThanRemovesOnlyOldArchives(t *testing.T) {
	folder := t.TempDir()
	writeArchive(t, folder, "old.tar.gz", 40*24*time.Hour)
	writeArchive(t, folder, "new.tar.gz", 2*24*time.Hour)
	writeArchive(t, folder, "notes.txt", 90*24*time.Hour)
	names, err := RemoveOlderThan(folder, time.Now().AddDate(0, 0, -30), false)
	if err != nil {
		t.Fatal(err)
	}
	if len(names) != 1 || names[0] != "old.tar.gz" {
		t.Fatalf("removed %v, want [old.tar.gz]", names)
	}
	if _, err := os.Stat(filepath.Join(folder, "new.tar.gz")); err != nil {
		t.Fatal("new.tar.gz was removed")
	}
}

func TestRemoveOlderThanDryRunRemovesNothing(t *testing.T) {
	folder := t.TempDir()
	writeArchive(t, folder, "old.tar.gz", 40*24*time.Hour)
	names, err := RemoveOlderThan(folder, time.Now().AddDate(0, 0, -30), true)
	if err != nil {
		t.Fatal(err)
	}
	if len(names) != 1 || names[0] != "old.tar.gz" {
		t.Fatalf("listed %v, want [old.tar.gz]", names)
	}
	if _, err := os.Stat(filepath.Join(folder, "old.tar.gz")); err != nil {
		t.Fatal("dry run removed old.tar.gz")
	}
}
GO

cat > cmd/backupctl/main.go <<'GO'
// Command backupctl does housekeeping for the nightly database backups.
package main

import (
	"flag"
	"fmt"
	"os"
	"time"

	"example.com/backupctl/internal/archive"
)

// usageText is printed when the command line can't be understood.
const usageText = "usage: backupctl prune -dir <folder> [-keep-days N] [-dry-run]"

func main() {
	if len(os.Args) < 2 || os.Args[1] != "prune" {
		fmt.Fprintln(os.Stderr, usageText)
		os.Exit(2)
	}
	pruneFlags := flag.NewFlagSet("prune", flag.ExitOnError)
	folder := pruneFlags.String("dir", "", "folder holding the archives")
	keepDays := pruneFlags.Int("keep-days", 30, "keep archives newer than this many days")
	dryRun := pruneFlags.Bool("dry-run", false, "list the archives prune would remove, and remove nothing")
	pruneFlags.Parse(os.Args[2:])
	if *folder == "" {
		fmt.Fprintln(os.Stderr, "prune: -dir is required")
		os.Exit(2)
	}
	cutoff := time.Now().AddDate(0, 0, -*keepDays)
	names, err := archive.RemoveOlderThan(*folder, cutoff, *dryRun)
	if err != nil {
		fmt.Fprintln(os.Stderr, "prune:", err)
		os.Exit(1)
	}
	verb := "removed"
	if *dryRun {
		verb = "would remove"
	}
	for _, name := range names {
		fmt.Println(verb, name)
	}
}
GO

cat > README.md <<'EOF'
# backupctl

`backupctl` keeps the nightly database backup folder tidy.

## Pruning

    backupctl prune -dir /var/backups/db -keep-days 30

Removes every `.tar.gz` archive in the folder that was last modified more
than `-keep-days` days ago (30 by default). Other files are left alone.

Add `-dry-run` to list the archives it would remove without removing any.

## Layout

- `cmd/backupctl`: the command line.
- `internal/archive`: discovering and removing archives.
EOF

