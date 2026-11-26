---
type: llm
---

The user asked for a quick picture of what calls Issue in internal/tokens/tokens.go, the method tokens.Service.Issue. Exactly three functions call it directly: Handlers.Signup (internal/httpapi/signup.go:66), Handlers.ResendVerification (internal/httpapi/signup.go:90) and Handlers.RequestPasswordReset (internal/httpapi/reset.go:16). Their routes are POST /signup, POST /signup/resend and POST /password-reset. Nothing else calls it: IssueAPIKey in internal/httpapi/apikeys.go has a similar name but makes its own random key, tokens.Service.Verify is a sibling method, and Login doesn't issue tokens. A caller may be named by its function or method, its route, its file, or file and line; a file and line at or near one of the three calls counts as that caller. This is Claude's final reply.
PASS if every caller the reply shows calling Issue directly is one of the three above, however it's named.
FAIL if the reply shows anything else as calling Issue directly, such as IssueAPIKey, CreateAPIKey, Verify, Login, main or a function the code doesn't have, or shows no caller at all. Count anything the reply doesn't show as a FAIL.
