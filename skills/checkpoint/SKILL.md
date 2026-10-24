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

Use these sections in this order, and leave out any that would be empty:

```markdown
# Checkpoint: <the task in one line>

_Saved before compaction. Read all of it before you continue._

## Goal
What the task is for and what finished looks like, in one to three sentences.

## Done
- Each completed step, with the files or symbols it touched.

## In progress
- What was being changed when you stopped, with `path:line`, and its state:
  builds or not, tested or not, half edited or not.

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
- A few sentences on how the pieces fit together, and what you understand now
  that you didn't at the start.
```

Be honest. If something is broken, untested or uncertain, say so: a checkpoint that overstates progress does more harm than none.

## Then tell the user

In your reply, give:

- the absolute path to `CHECKPOINT.md`;
- the exact message to paste first after compacting: **"Read `<path>/CHECKPOINT.md` in full, then continue the task."** Explain that the compacted conversation won't know the file exists unless they point to it;
- your suggestion of something worth remembering, if you noticed one.

Don't carry on with the task itself in this step; the user resumes it after compacting.
