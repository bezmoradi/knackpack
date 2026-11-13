#!/bin/sh
# PreCompact hook: print instructions for the summary Claude Code writes when
# it compacts a conversation, whether the developer runs /compact, the
# context reaches the auto-compact window, or Claude Code compacts a long
# session left idle before its prompt cache expires. Claude Code uses a
# PreCompact hook's stdout as instructions for that summary, together with
# any focus given to /compact and a "Compact instructions" section in
# CLAUDE.md, and cuts it at 10,000 characters.
#
# The summary quotes the developer's messages but keeps only a short version
# of what Claude worked out itself, such as a script's result or why something
# failed, which the next context then can't recall. These instructions ask it
# to keep that too, and Claude's last numbered questions word for word, since
# the developer may answer one with just a number. They also ask it to point
# the next context to a checkpoint saved for the task, which the intent hook
# does too, but only while intent tracking runs.
#
# It reads nothing but the environment, writes nothing, uses no network, and
# exits 0 on every failure, so it never blocks a compaction. Unlike
# knackpack's other hooks, it runs in headless `claude -p` runs and Agent SDK
# apps too, since it changes only what a summary keeps. KNACKPACK_COMPACT=off
# turns it off. `claude plugin eval` passes a case only variables named
# EVAL_*, so EVAL_KNACKPACK_COMPACT stands in for it there.

umask 077
trap 'exit 0' EXIT

setting=$(printf '%s' "${KNACKPACK_COMPACT:-${EVAL_KNACKPACK_COMPACT:-}}" | tr '[:upper:]' '[:lower:]')
case $setting in off | 0 | false | no) exit 0 ;; esac

cat <<'EOF'
From knackpack: this summary will already quote the developer's messages, but what you found out yourself is what summaries most often drop, so keep that too, with exact values:
- the results of the commands, scripts, tests and searches you ran: the numbers, names, paths and errors they produced;
- each cause you diagnosed, each explanation you gave and each decision you made, with its reason;
- the approaches you tried or rejected, and why;
- every file you created or changed, and where you saved reports, briefs, plans and checkpoints, by absolute path.
If your last reply asked the developer questions or offered numbered options, copy them word for word, with their numbering and the heading they sat under, since the developer may answer with just a number.
If you saved a checkpoint to resume the current task from, such as CHECKPOINT.md, say in the next step to read it in full before continuing, by its absolute path, and that this summary is newer where it covers later work.
EOF
