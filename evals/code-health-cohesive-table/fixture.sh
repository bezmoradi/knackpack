#!/bin/bash
# A Go upload service with a year of history. Its largest file by far,
# internal/filetype/types.go, is one table of accepted file types, one line per
# extension, with a lookup and focused tests; it changed in 3 of the 18 commits,
# each adding rows. Nothing in it is hard to change.
# Each commit writes every file at its step: a line ending in "#@N" exists from
# step N on, and one ending in "#@N-M" from step N until step M.
set -euo pipefail
git init -q -b main
git config user.name "Sam Okoro"
git config user.email "sam@example.com"
now=$(date +%s)
mkdir -p cmd/uploadd internal/filetype internal/scan internal/storage internal/upload

reveal() { # <step> <file>, the marked text on stdin
	awk -v k="$1" '
	match($0, / +#@[0-9]+(-[0-9]+)?$/) {
		m = substr($0, RSTART); sub(/^ +#@/, "", m); line = substr($0, 1, RSTART - 1)
		n = split(m, r, "-"); if (k + 0 >= r[1] + 0 && (n == 1 || k + 0 < r[2] + 0)) print line
		next
	}
	{ print }' > "$2"
}

put() { # <step> <first step> <text> <file>
	[ "$1" -ge "$2" ] || return 0
	printf '%s' "$3" | reveal "$1" "$4"
}

commit() { # <step> <days ago> <who> <message>
	local ts=$((now - $2 * 86400 - 3600 * ($2 % 7))) name email
	case $3 in
	sam) name="Sam Okoro" email=sam@example.com ;;
	lena) name="Lena Varga" email=lena@example.com ;;
	omar) name="Omar Haddad" email=omar@example.com ;;
	esac
	put "$1" 1 "$GOMOD" go.mod
	put "$1" 1 "$TYPES" internal/filetype/types.go
	put "$1" 1 "$TYPESTEST" internal/filetype/types_test.go
	put "$1" 1 "$HANDLER" internal/upload/handler.go
	put "$1" 3 "$HANDLERTEST" internal/upload/handler_test.go
	put "$1" 5 "$SCAN" internal/scan/scan.go
	put "$1" 1 "$DISK" internal/storage/disk.go
	put "$1" 1 "$MAIN" cmd/uploadd/main.go
	put "$1" 1 "$README" README.md
	git add -A
	GIT_AUTHOR_NAME=$name GIT_AUTHOR_EMAIL=$email GIT_COMMITTER_NAME=$name GIT_COMMITTER_EMAIL=$email \
		GIT_AUTHOR_DATE="$ts +0000" GIT_COMMITTER_DATE="$ts +0000" git commit -qm "$4"
}

IFS= read -r -d '' GOMOD <<'GO' || true
module example.com/uploads

go 1.22
GO

IFS= read -r -d '' TYPES <<'GO' || true
// Package filetype lists the file types uploads accept: each extension's MIME
// type, its kind, and whether browsers may show it inline.
package filetype

import (
	"path"
	"strings"
)

// Kind groups file types for size limits and content checks.
type Kind int

const (
	Image Kind = iota
	Video
	Audio
	Document
	Spreadsheet
	Presentation
	Archive
	Text
	Font  #@12
)

// Type is one accepted file type.
type Type struct {
	Ext    string
	MIME   string
	Kind   Kind
	Inline bool
}

// types is every accepted extension, grouped by kind. Inline is false for
// anything a browser could run script from or can't display.
var types = []Type{
	// Images
	{".apng", "image/apng", Image, true},
	{".avif", "image/avif", Image, true},  #@9
	{".bmp", "image/bmp", Image, true},
	{".djvu", "image/vnd.djvu", Image, false},
	{".gif", "image/gif", Image, true},
	{".heic", "image/heic", Image, false},  #@9
	{".heif", "image/heif", Image, false},  #@9
	{".ico", "image/vnd.microsoft.icon", Image, true},
	{".jpeg", "image/jpeg", Image, true},
	{".jpg", "image/jpeg", Image, true},
	{".png", "image/png", Image, true},
	{".psd", "image/vnd.adobe.photoshop", Image, false},
	{".svg", "image/svg+xml", Image, false},
	{".tif", "image/tiff", Image, false},
	{".tiff", "image/tiff", Image, false},
	{".webp", "image/webp", Image, true},

	// Video
	{".3g2", "video/3gpp2", Video, false},
	{".3gp", "video/3gpp", Video, false},
	{".asf", "video/x-ms-asf", Video, false},
	{".avi", "video/x-msvideo", Video, false},
	{".flv", "video/x-flv", Video, false},
	{".m4v", "video/x-m4v", Video, true},
	{".mkv", "video/x-matroska", Video, false},
	{".mov", "video/quicktime", Video, true},
	{".mp4", "video/mp4", Video, true},
	{".mpeg", "video/mpeg", Video, false},
	{".mpg", "video/mpeg", Video, false},
	{".ogv", "video/ogg", Video, true},
	{".ts", "video/mp2t", Video, false},
	{".webm", "video/webm", Video, true},
	{".wmv", "video/x-ms-wmv", Video, false},

	// Audio
	{".aac", "audio/aac", Audio, true},
	{".aif", "audio/aiff", Audio, false},
	{".aiff", "audio/aiff", Audio, false},
	{".amr", "audio/amr", Audio, false},
	{".au", "audio/basic", Audio, false},
	{".flac", "audio/flac", Audio, true},
	{".m4a", "audio/mp4", Audio, true},
	{".mid", "audio/midi", Audio, false},
	{".midi", "audio/midi", Audio, false},
	{".mp3", "audio/mpeg", Audio, true},
	{".oga", "audio/ogg", Audio, true},
	{".ogg", "audio/ogg", Audio, true},
	{".opus", "audio/opus", Audio, true},
	{".wav", "audio/wav", Audio, true},
	{".weba", "audio/webm", Audio, true},
	{".wma", "audio/x-ms-wma", Audio, false},

	// Documents
	{".abw", "application/x-abiword", Document, false},
	{".ai", "application/postscript", Document, false},
	{".azw", "application/vnd.amazon.ebook", Document, false},
	{".doc", "application/msword", Document, false},
	{".docx", "application/vnd.openxmlformats-officedocument.wordprocessingml.document", Document, false},
	{".eps", "application/postscript", Document, false},
	{".epub", "application/epub+zip", Document, false},
	{".mobi", "application/x-mobipocket-ebook", Document, false},
	{".odt", "application/vnd.oasis.opendocument.text", Document, false},
	{".pages", "application/vnd.apple.pages", Document, false},
	{".pdf", "application/pdf", Document, true},
	{".ps", "application/postscript", Document, false},
	{".rtf", "application/rtf", Document, false},
	{".xps", "application/vnd.ms-xpsdocument", Document, false},

	// Spreadsheets
	{".numbers", "application/vnd.apple.numbers", Spreadsheet, false},
	{".ods", "application/vnd.oasis.opendocument.spreadsheet", Spreadsheet, false},
	{".xls", "application/vnd.ms-excel", Spreadsheet, false},
	{".xlsm", "application/vnd.ms-excel.sheet.macroEnabled.12", Spreadsheet, false},
	{".xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", Spreadsheet, false},

	// Presentations
	{".key", "application/vnd.apple.keynote", Presentation, false},
	{".odp", "application/vnd.oasis.opendocument.presentation", Presentation, false},
	{".pps", "application/vnd.ms-powerpoint", Presentation, false},
	{".ppsx", "application/vnd.openxmlformats-officedocument.presentationml.slideshow", Presentation, false},
	{".ppt", "application/vnd.ms-powerpoint", Presentation, false},
	{".pptx", "application/vnd.openxmlformats-officedocument.presentationml.presentation", Presentation, false},

	// Archives
	{".7z", "application/x-7z-compressed", Archive, false},
	{".arc", "application/x-freearc", Archive, false},
	{".bz", "application/x-bzip", Archive, false},
	{".bz2", "application/x-bzip2", Archive, false},
	{".cab", "application/vnd.ms-cab-compressed", Archive, false},
	{".gz", "application/gzip", Archive, false},
	{".jar", "application/java-archive", Archive, false},
	{".lz", "application/x-lzip", Archive, false},
	{".lz4", "application/x-lz4", Archive, false},
	{".rar", "application/vnd.rar", Archive, false},
	{".tar", "application/x-tar", Archive, false},
	{".tgz", "application/gzip", Archive, false},
	{".xz", "application/x-xz", Archive, false},
	{".zip", "application/zip", Archive, false},
	{".zst", "application/zstd", Archive, false},

	// Text
	{".csv", "text/csv", Text, true},
	{".eml", "message/rfc822", Text, false},
	{".ics", "text/calendar", Text, false},
	{".json", "application/json", Text, true},
	{".jsonld", "application/ld+json", Text, false},
	{".log", "text/plain", Text, true},
	{".md", "text/markdown", Text, true},
	{".tsv", "text/tab-separated-values", Text, true},
	{".txt", "text/plain", Text, true},
	{".vcf", "text/vcard", Text, false},
	{".xml", "application/xml", Text, false},
	{".yaml", "application/yaml", Text, true},
	{".yml", "application/yaml", Text, true},
  #@12
	// Fonts  #@12
	{".eot", "application/vnd.ms-fontobject", Font, false},  #@12
	{".otf", "font/otf", Font, false},  #@12
	{".ttf", "font/ttf", Font, false},  #@12
	{".woff", "font/woff", Font, false},  #@12
	{".woff2", "font/woff2", Font, false},  #@12
}

// Lookup returns the type for a file name's extension, ignoring case.
func Lookup(name string) (Type, bool) {
	ext := strings.ToLower(path.Ext(name))
	for _, t := range types {
		if t.Ext == ext {
			return t, true
		}
	}
	return Type{}, false
}

// All returns every accepted type, in table order.
func All() []Type {
	return append([]Type(nil), types...)
}
GO

IFS= read -r -d '' TYPESTEST <<'GO' || true
package filetype

import (
	"strings"
	"testing"
)

func TestExtensionsAreUniqueLowercaseAndDotted(t *testing.T) {
	seen := make(map[string]bool)
	for _, typ := range All() {
		if typ.Ext != strings.ToLower(typ.Ext) || !strings.HasPrefix(typ.Ext, ".") {
			t.Errorf("extension %q must be lowercase and start with a dot", typ.Ext)
		}
		if seen[typ.Ext] {
			t.Errorf("%s is listed twice", typ.Ext)
		}
		seen[typ.Ext] = true
	}
}

func TestLookupIgnoresCase(t *testing.T) {
	for _, c := range []struct{ name, mime string }{
		{"photo.JPG", "image/jpeg"},
		{"report.pdf", "application/pdf"},
		{"backup.tar.gz", "application/gzip"},
	} {
		if got, ok := Lookup(c.name); !ok || got.MIME != c.mime {
			t.Errorf("Lookup(%q) = %q, %v; want %q", c.name, got.MIME, ok, c.mime)
		}
	}
	if _, ok := Lookup("setup.exe"); ok {
		t.Error("setup.exe was accepted")
	}
}

func TestScriptableTypesAreNotInline(t *testing.T) {
	for _, typ := range All() {
		if typ.Inline && (strings.Contains(typ.MIME, "svg") || strings.Contains(typ.MIME, "xml") || strings.Contains(typ.MIME, "html")) {
			t.Errorf("%s (%s) must not be shown inline", typ.Ext, typ.MIME)
		}
	}
}
GO

IFS= read -r -d '' HANDLER <<'GO' || true
// Package upload accepts file uploads over HTTP and serves them back.
package upload

import (
	"encoding/json"
	"errors"  #@7
	"fmt"  #@18
	"io"  #@5
	"log"  #@4
	"net/http"
	"os"  #@7

	"example.com/uploads/internal/filetype"
	"example.com/uploads/internal/scan"  #@5
	"example.com/uploads/internal/storage"
)
  #@11
// maxBody bounds a request body: the largest file limit plus room for the form.  #@11
const maxBody = 500<<20 + 1<<20  #@11

// Handler serves POST /files.  #@1-7
// Handler serves POST /files and GET /files/{id}.  #@7
type Handler struct {
	Store *storage.Disk
}
  #@2
// limit is the largest file of kind k that uploads accept, in bytes.  #@2
func limit(k filetype.Kind) int64 {  #@2
	switch k {  #@2
	case filetype.Video:  #@2
		return 500 << 20  #@2
	case filetype.Image, filetype.Audio:  #@2
		return 50 << 20  #@2
	default:  #@2
		return 20 << 20  #@2
	}  #@2
}  #@2

// Upload stores the form's file field and answers with its ID.
func (h *Handler) Upload(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, maxBody)  #@11
	file, header, err := r.FormFile("file")
	if err != nil {
		http.Error(w, "missing file field", http.StatusBadRequest)
		return
	}
	defer file.Close()
	t, ok := filetype.Lookup(header.Filename)
	if !ok {
		http.Error(w, "file type not accepted", http.StatusUnsupportedMediaType)  #@1-18
		http.Error(w, fmt.Sprintf("%s isn't an accepted file type", header.Filename), http.StatusUnsupportedMediaType)  #@18
		return
	}
	if header.Size > limit(t.Kind) {  #@2
		http.Error(w, "file too large", http.StatusRequestEntityTooLarge)  #@2
		return  #@2
	}  #@2
	head := make([]byte, 512)  #@5
	n, _ := io.ReadFull(file, head)  #@5
	if !scan.Matches(t, head[:n]) {  #@5
		http.Error(w, "contents don't match the file type", http.StatusUnsupportedMediaType)  #@5
		return  #@5
	}  #@5
	if _, err := file.Seek(0, io.SeekStart); err != nil {  #@5
		http.Error(w, "could not read the file", http.StatusInternalServerError)  #@5
		return  #@5
	}  #@5
	id, err := h.Store.Save(file, t)
	if err != nil {
		log.Printf("save upload: %v", err)  #@4
		http.Error(w, "could not store the file", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(map[string]string{"id": id})  #@1-14
	json.NewEncoder(w).Encode(map[string]string{"id": id, "type": t.MIME})  #@14
}
  #@7
// Download serves a stored file, inline only for types browsers show safely.  #@7
func (h *Handler) Download(w http.ResponseWriter, r *http.Request) {  #@7
	id := r.PathValue("id")  #@7
	t, ok := filetype.Lookup(id)  #@7
	if !ok {  #@7
		http.NotFound(w, r)  #@7
		return  #@7
	}  #@7
	f, err := h.Store.Open(id)  #@7
	if errors.Is(err, os.ErrNotExist) {  #@7
		http.NotFound(w, r)  #@7
		return  #@7
	}  #@7
	if err != nil {  #@7
		log.Printf("open upload: %v", err)  #@7
		http.Error(w, "could not read the file", http.StatusInternalServerError)  #@7
		return  #@7
	}  #@7
	defer f.Close()  #@7
	disposition := "attachment"  #@7
	if t.Inline {  #@7
		disposition = "inline"  #@7
	}  #@7
	w.Header().Set("Content-Type", t.MIME)  #@7
	w.Header().Set("Content-Disposition", disposition)  #@7
	w.Header().Set("X-Content-Type-Options", "nosniff")  #@8
	if _, err := io.Copy(w, f); err != nil {  #@7
		log.Printf("send upload %s: %v", id, err)  #@7
	}  #@7
}  #@7
GO

IFS= read -r -d '' HANDLERTEST <<'GO' || true
package upload

import (
	"bytes"
	"encoding/json"  #@15
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"testing"

	"example.com/uploads/internal/storage"
)

var png = []byte("\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01")

func post(t *testing.T, h *Handler, name string, data []byte) *httptest.ResponseRecorder {
	t.Helper()
	var body bytes.Buffer
	mw := multipart.NewWriter(&body)
	fw, err := mw.CreateFormFile("file", name)
	if err != nil {
		t.Fatal(err)
	}
	fw.Write(data)
	mw.Close()
	req := httptest.NewRequest(http.MethodPost, "/files", &body)
	req.Header.Set("Content-Type", mw.FormDataContentType())
	rec := httptest.NewRecorder()
	h.Upload(rec, req)
	return rec
}

func TestUploadStoresAcceptedType(t *testing.T) {
	h := &Handler{Store: &storage.Disk{Root: t.TempDir()}}
	if rec := post(t, h, "photo.png", png); rec.Code != http.StatusCreated {
		t.Fatalf("status %d: %s", rec.Code, rec.Body)
	}
}

func TestUploadRejectsUnknownType(t *testing.T) {
	h := &Handler{Store: &storage.Disk{Root: t.TempDir()}}
	if rec := post(t, h, "setup.exe", []byte("MZ")); rec.Code != http.StatusUnsupportedMediaType {
		t.Fatalf("status %d", rec.Code)
	}
}
  #@15
func TestUploadRejectsContentsOfAnotherType(t *testing.T) {  #@15
	h := &Handler{Store: &storage.Disk{Root: t.TempDir()}}  #@15
	if rec := post(t, h, "photo.png", []byte("<html><script>alert(1)</script>")); rec.Code != http.StatusUnsupportedMediaType {  #@15
		t.Fatalf("status %d", rec.Code)  #@15
	}  #@15
}  #@15
  #@15
func TestDownloadServesImagesInline(t *testing.T) {  #@15
	h := &Handler{Store: &storage.Disk{Root: t.TempDir()}}  #@15
	var created struct{ ID string }  #@15
	if err := json.Unmarshal(post(t, h, "photo.png", png).Body.Bytes(), &created); err != nil {  #@15
		t.Fatal(err)  #@15
	}  #@15
	req := httptest.NewRequest(http.MethodGet, "/files/"+created.ID, nil)  #@15
	req.SetPathValue("id", created.ID)  #@15
	rec := httptest.NewRecorder()  #@15
	h.Download(rec, req)  #@15
	if rec.Code != http.StatusOK || !bytes.Equal(rec.Body.Bytes(), png) || rec.Header().Get("Content-Disposition") != "inline" {  #@15
		t.Fatalf("status %d, disposition %q", rec.Code, rec.Header().Get("Content-Disposition"))  #@15
	}  #@15
}  #@15
GO

IFS= read -r -d '' SCAN <<'GO' || true
// Package scan checks that a file's first bytes fit the type its name claims.
package scan

import (
	"net/http"
	"strings"

	"example.com/uploads/internal/filetype"
)

// Matches reports whether head, a file's first bytes, fits t.
func Matches(t filetype.Type, head []byte) bool {
	sniffed := http.DetectContentType(head)
	if strings.HasPrefix(sniffed, "text/html") && t.Kind != filetype.Text {  #@10
		return false  #@10
	}  #@10
	switch t.Kind {
	case filetype.Image:
		return strings.HasPrefix(sniffed, "image/") || sniffed == "application/octet-stream" || t.MIME == "image/svg+xml"
	case filetype.Text:
		return strings.HasPrefix(sniffed, "text/")
	default:
		return true
	}
}
GO

IFS= read -r -d '' DISK <<'GO' || true
// Package storage keeps uploaded files on local disk.
package storage

import (
	"crypto/rand"
	"encoding/hex"
	"io"
	"os"
	"path/filepath"
	"strings"  #@7

	"example.com/uploads/internal/filetype"
)

// Disk stores files under Root, each named by a random ID and its extension.
type Disk struct {
	Root string
}

// Save writes r to a new file and returns its ID.
func (d *Disk) Save(r io.Reader, t filetype.Type) (string, error) {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	id := hex.EncodeToString(b) + t.Ext
	f, err := os.Create(filepath.Join(d.Root, id))  #@1-6
	f, err := os.CreateTemp(d.Root, ".upload-*")  #@6
	if err != nil {
		return "", err
	}
	defer os.Remove(f.Name())  #@6
	if _, err := io.Copy(f, r); err != nil {
		f.Close()
		return "", err
	}
	if err := f.Sync(); err != nil {  #@17
		f.Close()  #@17
		return "", err  #@17
	}  #@17
	if err := f.Close(); err != nil {
		return "", err
	}
	return id, nil  #@1-6
	return id, os.Rename(f.Name(), filepath.Join(d.Root, id))  #@6
}
  #@7
// Open returns the stored file with the given ID.  #@7
func (d *Disk) Open(id string) (*os.File, error) {  #@7
	if id != filepath.Base(id) || strings.HasPrefix(id, ".") {  #@7
		return nil, os.ErrNotExist  #@7
	}  #@7
	return os.Open(filepath.Join(d.Root, id))  #@7
}  #@7
GO

IFS= read -r -d '' MAIN <<'GO' || true
// Command uploadd accepts file uploads and serves them back.
package main

import (
	"context"  #@16
	"flag"  #@13
	"log"
	"net/http"
	"os"  #@16
	"os/signal"  #@16
	"syscall"  #@16
	"time"

	"example.com/uploads/internal/storage"
	"example.com/uploads/internal/upload"
)

func main() {
	addr := flag.String("addr", "127.0.0.1:8080", "address to listen on")  #@13
	root := flag.String("root", "/var/lib/uploadd", "folder to keep files in")  #@13
	flag.Parse()  #@13
	h := &upload.Handler{Store: &storage.Disk{Root: "/var/lib/uploadd"}}  #@1-13
	h := &upload.Handler{Store: &storage.Disk{Root: *root}}  #@13
	mux := http.NewServeMux()
	mux.HandleFunc("POST /files", h.Upload)
	mux.HandleFunc("GET /files/{id}", h.Download)  #@7
	srv := &http.Server{Addr: "127.0.0.1:8080", Handler: mux, ReadHeaderTimeout: 10 * time.Second}  #@1-13
	srv := &http.Server{Addr: *addr, Handler: mux, ReadHeaderTimeout: 10 * time.Second}  #@13
	log.Fatal(srv.ListenAndServe())  #@1-16
	go func() {  #@16
		if err := srv.ListenAndServe(); err != http.ErrServerClosed {  #@16
			log.Fatal(err)  #@16
		}  #@16
	}()  #@16
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)  #@16
	defer stop()  #@16
	<-ctx.Done()  #@16
	shutdown, cancel := context.WithTimeout(context.Background(), 30*time.Second)  #@16
	defer cancel()  #@16
	if err := srv.Shutdown(shutdown); err != nil {  #@16
		log.Printf("shutdown: %v", err)  #@16
	}  #@16
}
GO

IFS= read -r -d '' README <<'MD' || true
# uploadd

Accepts file uploads and serves them back.

    POST /files       multipart form with a "file" field; answers {"id": "..."}
    GET  /files/{id}  #@7

The accepted file types, with their MIME types and whether browsers may show
them inline, are the table in `internal/filetype/types.go`: add a type there.

## Development

    go vet ./... && go test ./...
MD

commit 1 350 sam "Accept uploads and store them on disk"
commit 2 340 sam "Reject files over the size limit for their kind"
commit 3 322 lena "Tests for the upload handler"
commit 4 310 lena "Log failed saves"
commit 5 290 sam "Check a file's first bytes against its claimed type"
commit 6 270 omar "Write uploads to a temp file and rename"
commit 7 250 omar "GET /files/{id}"
commit 8 231 lena "Serve downloads with nosniff"
commit 9 210 sam "Accept HEIC and AVIF photos"
commit 10 190 omar "Reject HTML disguised as another type"
commit 11 170 lena "Cap request bodies"
commit 12 150 sam "Accept font files"
commit 13 128 omar "Configurable address and storage folder"
commit 14 105 lena "Return the stored MIME type"
commit 15 80 sam "Test content checks and downloads"
commit 16 60 omar "Shut down cleanly on SIGTERM"
commit 17 35 lena "Fsync uploads before renaming"
commit 18 14 sam "Name the rejected file in the error"
