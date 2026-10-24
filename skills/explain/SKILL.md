---
name: explain
description: Explain what was just implemented in this conversation in plain English for a junior dev, so the user can understand the full picture and make a decision. Default output is exactly two paragraphs; the argument "more" gives a longer, detailed version.
argument-hint: "[more | topic]"
---

# Explain What You Just Did

Summarize the work you just completed in this conversation (the most recent implementation, fix, or change) in plain English, written for a junior developer who has not been following along. If nothing was built or changed in this conversation, or nothing on the topic you were given, say so in one sentence instead of explaining something else.

## Output contract (default: no arguments)

- **Exactly two paragraphs.** Not one, not three. No headers, no bullet points, no numbered lists, no code blocks, no tables.
- **Paragraph 1 — the what and why:** what problem existed or what was requested, and what was built or changed to address it, at the conceptual level. Name the services/files only when knowing them changes the reader's understanding.
- **Paragraph 2 — how it works and what it means:** how the pieces fit together end to end, any trade-offs or decisions that were made along the way, and anything the reader would need to know to make a decision about the work (risks, follow-ups, alternatives that were rejected and why, and what was and wasn't tested).
- **Plain English throughout.** Expand or briefly define any jargon, acronym, or project-specific codename on first use. Write as if to a capable junior dev: no condescension, but no assumed context either.
- **No process narration.** Do not describe the sequence of tool calls, searches, or edits you performed — describe the resulting design and behavior.
- Do not end with questions or offers ("let me know if..."). The user will ask for more if they want it.

## With arguments

- `more` (or `detail`, `details`, `deep`): produce a longer, detailed version — 4 to 8 paragraphs. Structure is still prose-first, but short code snippets and file references are allowed where they genuinely aid understanding. Cover edge cases, error handling, and data flow explicitly. Same plain-English, junior-dev register.
- `<topic>`: apply the default two-paragraph contract, but scope the explanation to the named topic/change instead of the most recent work.
- `more <topic>`: the longer version, scoped to the named topic.
