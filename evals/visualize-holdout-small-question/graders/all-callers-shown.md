---
type: llm
---

The user asked for a quick picture of what calls Issue in internal/tokens/tokens.go, the method tokens.Service.Issue. Exactly three functions call it directly: Handlers.Signup (internal/httpapi/signup.go:66), Handlers.ResendVerification (internal/httpapi/signup.go:90) and Handlers.RequestPasswordReset (internal/httpapi/reset.go:16). Their routes are POST /signup, POST /signup/resend and POST /password-reset. Nothing else calls it: IssueAPIKey in internal/httpapi/apikeys.go has a similar name but makes its own random key, tokens.Service.Verify is a sibling method, and Login doesn't issue tokens. A caller may be named by its function or method, its route, its file, or file and line; a file and line at or near one of the three calls counts as that caller. This is Claude's final reply.
PASS if the reply shows all three direct callers: Signup, ResendVerification and RequestPasswordReset, by name, route or file and line.
FAIL if any of the three is missing from the reply. Count anything the reply doesn't show as a FAIL.
