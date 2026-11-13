---
name: checkpoint
description: Save the current task's state to CHECKPOINT.md before the user compacts the conversation, so the next context picks up exactly where this one stopped instead of relying on the automatic summary. Use when the user is about to compact, worries the conversation has grown too long, or asks to save where things stand. It writes one temporary file and doesn't touch the memory system.
---

# Save task state before compaction

Compaction replaces the conversation with a summary, and summaries drop the details that matter most when you resume: the exact line being changed, why an option was rejected, the trap found an hour ago, the very next step. Write those down now, in a file the next context reads first.

## Where to save it

Use the session scratchpad named in your system prompt, if there is one. Otherwise run `printenv TMPDIR` once (use `/tmp` if it prints nothing) and use the folder `claude-${CLAUDE_SESSION_ID}` inside it, writing the folder's full path literally in every later command. Create it with `mkdir -p -m 700 <folder>`, then check it with `[ -d <folder> ] && [ ! -L <folder> ] && [ -O <folder> ] && chmod 700 <folder>`; if the check fails, stop and tell the user. Never write into the repository unless the user asks.

Save the file as `CHECKPOINT.md` in that folder, replacing any earlier one: only the latest state matters.

The file is temporary and belongs to this task. Don't copy it, or anything from it, into the memory system. If you notice something worth remembering beyond this task, such as a lasting preference of the user's, mention it in one line and let the user decide.

## How to write it

Go back through the whole conversation, not just the last few turns, and record what actually happened. Be specific: real paths, `path:line` locations, symbol names and commands. "Was working on the auth code" helps nobody after compaction.

The summary quotes the developer's messages but keeps only a short version of what you found out yourself, so spend the checkpoint on that: the results of commands and scripts you ran, with their exact numbers, the causes you diagnosed and why, and where you saved anything.

If knackpack's intent tracking keeps a record for this session, give its path under Context rather than copying its requirements: it already survives compaction.

If your last reply asked the user something or offered options, copy those questions and lists under Open questions word for word, keeping each list's numbering and the heading it sat under, and note that the user may answer by number. After compaction the user often answers with just "1", and relabeled or merged lists make that answer ambiguous, or point it at the wrong option.

Use these sections in this order, and leave out any that would be empty:

```markdown
# Checkpoint: <the task in one line>

_Saved before compaction. Read all of it, then compare it with the repository
(branch, commit, uncommitted files) before acting on it: it records the work as
it was when saved. Where they differ, trust the repository and say what
changed._

## Goal
What the task is for and what finished looks like, in one to three sentences.

## Done
- Each completed step, with the files or symbols it touched and what it
  found, with exact values.

## In progress
- What was being changed when you stopped, with `path:line`, and its state:
  builds or not, tested or not, half edited or not.
- Each subagent or command still running in the background: what it was
  asked, its ID, and where its result will land.

## Next steps
1. The very next action, specific enough to start without rereading anything.
2. The steps after it, in order.

## Decisions
- Each decision, and why it beat the alternative.

## Open questions
- What's waiting on the user, unresolved choices, and anything ambiguous.

## Gotchas
- Non-obvious things learned along the way: a failing edge case, a lint rule,
  a contract between services, an environment-specific guard, a rule from the
  project's instructions.

## Context
- Each checkout or worktree in use: its absolute path, branch, the output of
  `git rev-parse --short HEAD`, and whether it has uncommitted changes.
- A few sentences on how the pieces fit together, and what you understand now
  that you didn't at the start.
```

Be honest. If something is broken, untested or uncertain, say so: a checkpoint that overstates progress does more harm than none.

## Then tell the user

In your reply, give:

- the absolute path to `CHECKPOINT.md`;
- what to do next, in this order: run `/compact`, unless they typed it while you were writing, since Claude Code holds a command typed during a reply and runs it when the reply ends; then just send their next message. Say there's nothing to paste: the compacted conversation won't know the file exists unless something points to it, and knackpack's hooks do, since the session-start hook points to the file when it's in the `claude-<session>` folder or, from Claude Code 2.1.257, in the session's scratchpad, and the compaction focus asks the summary to name it;
- the fallback, for when the first thing Claude does after compacting isn't reading the file, such as when intent tracking is off: paste **"Read `<path>/CHECKPOINT.md` in full, then continue the task."**;
- your suggestion of something worth remembering, if you noticed one.

Don't carry on with the task itself in this step; the user resumes it after compacting.
