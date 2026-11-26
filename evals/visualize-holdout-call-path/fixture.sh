#!/bin/bash
# A small Go accounts service. POST /signup goes Signup -> decodeSignup ->
# validateSignup (which asks UserStore.EmailTaken) -> UserStore.Create ->
# tokens.Issue("verify-email") -> Mailer.SendVerification -> 201. The rate
# limiter and the audit log are wired only on POST /login, never on the
# signup path. tokens.Issue has three direct callers: Signup,
# ResendVerification and RequestPasswordReset; IssueAPIKey and tokens.Verify
# have similar names and don't call it.
set -euo pipefail
export GIT_AUTHOR_DATE="2026-11-04T10:10:00Z" GIT_COMMITTER_DATE="2026-11-04T10:10:00Z"
git init -q -b main
git config user.name "Alex Morgan"
git config user.email "alex@example.com"
mkdir -p cmd/server internal/httpapi internal/store internal/tokens internal/mail internal/ratelimit internal/audit

cat > go.mod <<'EOF'
module example.com/accounts

go 1.23

require (
	github.com/jackc/pgx/v5 v5.7.1
	golang.org/x/crypto v0.29.0
)
EOF

cat > README.md <<'EOF'
# accounts

Sign-up, login, email verification and password reset. `cmd/server` wires the
routes; Postgres holds users and tokens.
EOF

cat > cmd/server/main.go <<'EOF'
package main

import (
	"database/sql"
	"log"
	"net/http"
	"os"
	"time"

	_ "github.com/jackc/pgx/v5/stdlib"

	"example.com/accounts/internal/audit"
	"example.com/accounts/internal/httpapi"
	"example.com/accounts/internal/mail"
	"example.com/accounts/internal/ratelimit"
	"example.com/accounts/internal/store"
	"example.com/accounts/internal/tokens"
)

func main() {
	db, err := sql.Open("pgx", os.Getenv("ACCOUNTS_DATABASE_URL"))
	if err != nil {
		log.Fatal(err)
	}
	h := &httpapi.Handlers{
		Users:  store.NewUserStore(db),
		Tokens: tokens.NewService(db),
		Mailer: mail.NewMailer(os.Getenv("ACCOUNTS_SMTP_ADDR"), "no-reply@example.com"),
		Audit:  audit.NewLog(db),
	}
	limiter := ratelimit.New(5, time.Minute)

	mux := http.NewServeMux()
	mux.HandleFunc("POST /signup", h.Signup)
	mux.HandleFunc("POST /signup/resend", h.ResendVerification)
	mux.Handle("POST /login", limiter.Wrap(http.HandlerFunc(h.Login)))
	mux.HandleFunc("POST /password-reset", h.RequestPasswordReset)
	mux.HandleFunc("POST /api-keys", h.CreateAPIKey)

	log.Fatal(http.ListenAndServe(":8080", mux))
}
EOF

cat > internal/httpapi/handlers.go <<'EOF'
package httpapi

import (
	"encoding/json"
	"net/http"

	"example.com/accounts/internal/audit"
	"example.com/accounts/internal/mail"
	"example.com/accounts/internal/store"
	"example.com/accounts/internal/tokens"
)

type Handlers struct {
	Users  *store.UserStore
	Tokens *tokens.Service
	Mailer *mail.Mailer
	Audit  *audit.Log
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}
EOF

cat > internal/httpapi/signup.go <<'EOF'
package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/mail"
	"strings"

	"example.com/accounts/internal/store"
)

type signupRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
	Name     string `json:"name"`
}

var errEmailTaken = errors.New("email already registered")

func decodeSignup(r *http.Request) (signupRequest, error) {
	var req signupRequest
	err := json.NewDecoder(http.MaxBytesReader(nil, r.Body, 1<<16)).Decode(&req)
	req.Email = strings.ToLower(strings.TrimSpace(req.Email))
	return req, err
}

func (h *Handlers) validateSignup(ctx context.Context, req signupRequest) error {
	if _, err := mail.ParseAddress(req.Email); err != nil {
		return errors.New("invalid email")
	}
	if len(req.Password) < 12 {
		return errors.New("password must be at least 12 characters")
	}
	taken, err := h.Users.EmailTaken(ctx, req.Email)
	if err != nil {
		return err
	}
	if taken {
		return errEmailTaken
	}
	return nil
}

// Signup creates an unverified account and emails a verification link.
func (h *Handlers) Signup(w http.ResponseWriter, r *http.Request) {
	req, err := decodeSignup(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "bad_json"})
		return
	}
	if err := h.validateSignup(r.Context(), req); err != nil {
		status := http.StatusUnprocessableEntity
		if errors.Is(err, errEmailTaken) {
			status = http.StatusConflict
		}
		writeJSON(w, status, map[string]string{"error": err.Error()})
		return
	}
	user, err := h.Users.Create(r.Context(), store.NewUser{Email: req.Email, Name: req.Name, Password: req.Password})
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
		return
	}
	token, err := h.Tokens.Issue(r.Context(), user.ID, "verify-email")
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
		return
	}
	if err := h.Mailer.SendVerification(user.Email, user.Name, token); err != nil {
		// The account exists; the user can ask for the email again.
		writeJSON(w, http.StatusAccepted, map[string]string{"id": user.ID, "email": "not_sent"})
		return
	}
	writeJSON(w, http.StatusCreated, map[string]string{"id": user.ID})
}

// ResendVerification sends a new verification link to an unverified user.
func (h *Handlers) ResendVerification(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Email string `json:"email"`
	}
	_ = json.NewDecoder(r.Body).Decode(&req)
	user, err := h.Users.ByEmail(r.Context(), strings.ToLower(req.Email))
	if err != nil || user.Verified {
		w.WriteHeader(http.StatusAccepted)
		return
	}
	token, err := h.Tokens.Issue(r.Context(), user.ID, "verify-email")
	if err == nil {
		_ = h.Mailer.SendVerification(user.Email, user.Name, token)
	}
	w.WriteHeader(http.StatusAccepted)
}
EOF

cat > internal/httpapi/login.go <<'EOF'
package httpapi

import (
	"encoding/json"
	"net/http"
	"strings"
)

func (h *Handlers) Login(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "bad_json"})
		return
	}
	user, err := h.Users.CheckPassword(r.Context(), strings.ToLower(req.Email), req.Password)
	if err != nil {
		h.Audit.Record(r.Context(), "login_failed", req.Email)
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "invalid_credentials"})
		return
	}
	h.Audit.Record(r.Context(), "login", user.ID)
	writeJSON(w, http.StatusOK, map[string]string{"id": user.ID})
}
EOF

cat > internal/httpapi/reset.go <<'EOF'
package httpapi

import (
	"encoding/json"
	"net/http"
	"strings"
)

func (h *Handlers) RequestPasswordReset(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Email string `json:"email"`
	}
	_ = json.NewDecoder(r.Body).Decode(&req)
	user, err := h.Users.ByEmail(r.Context(), strings.ToLower(req.Email))
	if err == nil {
		token, err := h.Tokens.Issue(r.Context(), user.ID, "password-reset")
		if err == nil {
			_ = h.Mailer.SendPasswordReset(user.Email, token)
		}
	}
	// Same answer whether or not the address exists.
	w.WriteHeader(http.StatusAccepted)
}
EOF

cat > internal/httpapi/apikeys.go <<'EOF'
package httpapi

import (
	"crypto/rand"
	"encoding/hex"
	"net/http"
)

// IssueAPIKey makes a random key; API keys aren't tokens.Service tokens.
func IssueAPIKey() (string, error) {
	b := make([]byte, 24)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return "ak_" + hex.EncodeToString(b), nil
}

func (h *Handlers) CreateAPIKey(w http.ResponseWriter, r *http.Request) {
	key, err := IssueAPIKey()
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
		return
	}
	writeJSON(w, http.StatusCreated, map[string]string{"key": key})
}
EOF

cat > internal/store/users.go <<'EOF'
package store

import (
	"context"
	"database/sql"
	"errors"

	"golang.org/x/crypto/bcrypt"
)

type User struct {
	ID       string
	Email    string
	Name     string
	Verified bool
}

type NewUser struct {
	Email, Name, Password string
}

type UserStore struct{ db *sql.DB }

func NewUserStore(db *sql.DB) *UserStore { return &UserStore{db: db} }

func (s *UserStore) EmailTaken(ctx context.Context, email string) (bool, error) {
	var n int
	err := s.db.QueryRowContext(ctx, `SELECT count(*) FROM users WHERE email = $1`, email).Scan(&n)
	return n > 0, err
}

func (s *UserStore) Create(ctx context.Context, u NewUser) (User, error) {
	hash, err := bcrypt.GenerateFromPassword([]byte(u.Password), bcrypt.DefaultCost)
	if err != nil {
		return User{}, err
	}
	var id string
	err = s.db.QueryRowContext(ctx,
		`INSERT INTO users (email, name, password_hash) VALUES ($1, $2, $3) RETURNING id`,
		u.Email, u.Name, hash).Scan(&id)
	return User{ID: id, Email: u.Email, Name: u.Name}, err
}

func (s *UserStore) ByEmail(ctx context.Context, email string) (User, error) {
	var u User
	err := s.db.QueryRowContext(ctx, `SELECT id, email, name, verified FROM users WHERE email = $1`, email).
		Scan(&u.ID, &u.Email, &u.Name, &u.Verified)
	return u, err
}

var ErrBadPassword = errors.New("bad password")

func (s *UserStore) CheckPassword(ctx context.Context, email, password string) (User, error) {
	var u User
	var hash []byte
	err := s.db.QueryRowContext(ctx, `SELECT id, email, name, verified, password_hash FROM users WHERE email = $1`, email).
		Scan(&u.ID, &u.Email, &u.Name, &u.Verified, &hash)
	if err != nil {
		return User{}, err
	}
	if bcrypt.CompareHashAndPassword(hash, []byte(password)) != nil {
		return User{}, ErrBadPassword
	}
	return u, nil
}
EOF

cat > internal/tokens/tokens.go <<'EOF'
package tokens

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"time"
)

type Service struct{ db *sql.DB }

func NewService(db *sql.DB) *Service { return &Service{db: db} }

// Issue stores a hash of a new random token for the user and purpose, valid
// for 24 hours, and returns the token itself.
func (s *Service) Issue(ctx context.Context, userID, purpose string) (string, error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	token := hex.EncodeToString(b)
	sum := sha256.Sum256([]byte(token))
	_, err := s.db.ExecContext(ctx,
		`INSERT INTO tokens (user_id, purpose, hash, expires_at) VALUES ($1, $2, $3, $4)`,
		userID, purpose, hex.EncodeToString(sum[:]), time.Now().Add(24*time.Hour))
	return token, err
}

// Verify reports whether the token is current for the purpose and returns
// its user.
func (s *Service) Verify(ctx context.Context, token, purpose string) (string, bool) {
	sum := sha256.Sum256([]byte(token))
	var userID string
	err := s.db.QueryRowContext(ctx,
		`SELECT user_id FROM tokens WHERE hash = $1 AND purpose = $2 AND expires_at > now()`,
		hex.EncodeToString(sum[:]), purpose).Scan(&userID)
	return userID, err == nil
}
EOF

cat > internal/mail/mailer.go <<'EOF'
package mail

import (
	"fmt"
	"net/smtp"
)

type Mailer struct {
	addr, from string
}

func NewMailer(addr, from string) *Mailer { return &Mailer{addr: addr, from: from} }

func (m *Mailer) send(to, subject, body string) error {
	msg := fmt.Sprintf("From: %s\r\nTo: %s\r\nSubject: %s\r\n\r\n%s", m.from, to, subject, body)
	return smtp.SendMail(m.addr, nil, m.from, []string{to}, []byte(msg))
}

func (m *Mailer) SendVerification(to, name, token string) error {
	return m.send(to, "Confirm your email",
		fmt.Sprintf("Hi %s,\n\nConfirm your address: https://accounts.example.com/verify?token=%s\n", name, token))
}

func (m *Mailer) SendPasswordReset(to, token string) error {
	return m.send(to, "Reset your password",
		fmt.Sprintf("Reset it here: https://accounts.example.com/reset?token=%s\n", token))
}
EOF

cat > internal/ratelimit/limiter.go <<'EOF'
package ratelimit

import (
	"net"
	"net/http"
	"sync"
	"time"
)

// Limiter allows n requests per window per client IP.
type Limiter struct {
	mu     sync.Mutex
	n      int
	window time.Duration
	seen   map[string][]time.Time
}

func New(n int, window time.Duration) *Limiter {
	return &Limiter{n: n, window: window, seen: map[string][]time.Time{}}
}

func (l *Limiter) Wrap(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ip, _, _ := net.SplitHostPort(r.RemoteAddr)
		if !l.allow(ip, time.Now()) {
			w.WriteHeader(http.StatusTooManyRequests)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func (l *Limiter) allow(key string, now time.Time) bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	recent := l.seen[key][:0]
	for _, t := range l.seen[key] {
		if now.Sub(t) < l.window {
			recent = append(recent, t)
		}
	}
	if len(recent) >= l.n {
		l.seen[key] = recent
		return false
	}
	l.seen[key] = append(recent, now)
	return true
}
EOF

cat > internal/audit/audit.go <<'EOF'
package audit

import (
	"context"
	"database/sql"
)

type Log struct{ db *sql.DB }

func NewLog(db *sql.DB) *Log { return &Log{db: db} }

func (l *Log) Record(ctx context.Context, event, subject string) {
	_, _ = l.db.ExecContext(ctx, `INSERT INTO audit_log (event, subject) VALUES ($1, $2)`, event, subject)
}
EOF

git add -A
git commit -qm "Accounts service: signup, verification, login and password reset"
