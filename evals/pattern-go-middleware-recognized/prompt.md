---
description: Asked to design a Decorator for request logging around net/http handlers, the assessment points at the standard http.Handler wrapping that the library already supports and designs no new handler interface or type hierarchy. The request asks for a design, so nothing is edited.
expected_outcome: Standard middleware (a function from http.Handler to http.Handler, or the equivalent) is recommended; no custom handler interface or type per concern; no file is edited.
tags: [pattern, pattern-dev]
max_turns: 20
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Edit, Agent]
---

I want to add request logging around every handler in server/ with the Decorator pattern. Select the right design for it and show me the shape before anyone writes code.

I can't open files on this machine, so put the full review in your reply, exactly as written.
