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
# to keep that too, how the developer asked the work to be done, which a
# summary can drop while keeping what was built, and Claude's last numbered
# questions word for word, since the developer may answer one with just a
# number. They also ask it to point
# the next context to a checkpoint saved for the task, which the intent hook
# does too, but only while intent tracking runs.
#
# With KNACKPACK_COMPACT_GATE=on, which is off by default, it also stops a
# manual /compact in an attended session that has no checkpoint saved since
# its last compaction, and tells the developer to run /knackpack:checkpoint
# first: a hook can't make Claude write the checkpoint, since Claude gets no
# turn between /compact and the compaction. Claude Code shows a manual
# /compact's blocking message from stderr, and exit 2 blocks it. "/compact
# skip-checkpoint" goes ahead once without one. An automatic compaction is
# never blocked, since blocking one that recovers from a context-limit error
# fails the request, and neither is a headless run, where no one may be there
# to answer. To know what "since its last compaction" means, the gate touches
# a file named after the session in its own state folder each time it lets a
# compaction through, and a checkpoint counts when it's newer than that file.
# Whenever the gate can't decide, such as without a session ID or a state
# folder it owns, it lets the compaction through.
#
# Without the gate it reads nothing but the environment and writes nothing;
# it never uses the network and exits 0 on every failure. Unlike knackpack's
# other hooks, it prints its instructions in headless `claude -p` runs and
# Agent SDK apps too, since they change only what a summary keeps.
# KNACKPACK_COMPACT=off turns the instructions off, not the gate. `claude
# plugin eval` passes a case only variables named EVAL_*, so
# EVAL_KNACKPACK_COMPACT and EVAL_KNACKPACK_COMPACT_GATE stand in for them
# there.

umask 077
trap 'exit 0' EXIT

field() {
	printf '%s\n' "$input" | awk -v k="$1" '
	match($0, "\"" k "\"[ \t]*:[ \t]*\"[^\"]*\"") {
		s = substr($0, RSTART, RLENGTH)
		sub(/^"[^"]*"[ \t]*:[ \t]*"/, "", s)
		print substr(s, 1, length(s) - 1)
		exit
	}'
}

# Prints the marker file to touch when the compaction may go ahead, prints
# nothing when the gate is off or can't decide, and returns 1 when it blocks.
gate() {
	gs=$(printf '%s' "${KNACKPACK_COMPACT_GATE:-${EVAL_KNACKPACK_COMPACT_GATE:-}}" | tr '[:upper:]' '[:lower:]')
	case $gs in on | 1 | true | yes) ;; *) return 0 ;; esac
	# Claude Code sets these for hooks: sdk-cli and 0 under `claude -p`,
	# cli and 1 in an attended session, cli and 0 under `claude --bg`, which
	# a person may still be chatting with. Missing values count as attended.
	case ${CLAUDE_CODE_ENTRYPOINT:-} in
	sdk-*) [ "${CLAUDE_CODE_SESSION_ATTENDED:-}" = 1 ] || return 0 ;;
	'') [ "${CLAUDE_CODE_SESSION_ATTENDED:-}" = 0 ] && return 0 ;;
	esac
	input=$(cat)
	sid=$(field session_id)
	case $sid in '' | *[!A-Za-z0-9-]*) return 0 ;; esac
	[ "${#sid}" -le 64 ] || return 0
	base=${XDG_STATE_HOME:-}
	case $base in /*) ;; *) base=${HOME:-}/.local/state ;; esac
	case $base in /*) ;; *) return 0 ;; esac
	dir=$base/knackpack/compact
	if [ ! -d "$dir" ]; then mkdir -p "$dir" 2>/dev/null || return 0; fi
	[ -d "$dir" ] && [ ! -L "$dir" ] && [ -O "$dir" ] || return 0
	chmod 700 "$dir" 2>/dev/null || return 0
	m=$dir/$sid
	[ ! -L "$m" ] || return 0
	[ ! -e "$m" ] || [ -O "$m" ] || return 0
	# Markers of sessions left untouched for 30 days.
	find "$dir" -type f -mtime +30 -exec rm -f {} + 2>/dev/null
	[ "$(field trigger)" = manual ] || { printf '%s\n' "$m"; return 0; }
	case $(field custom_instructions | tr '[:upper:]' '[:lower:]') in
	*skip-checkpoint*) printf '%s\n' "$m"; return 0 ;;
	esac
	pad=$(field scratchpad_dir)
	case $pad in /*) ;; *) pad= ;; esac
	# Without the trailing slash macOS's TMPDIR has, which would double.
	t=${TMPDIR:-/tmp}
	t=${t%"${t##*[!/]}"}
	for f in ${pad:+"$pad/CHECKPOINT.md"} "$t/claude-$sid/CHECKPOINT.md" "/tmp/claude-$sid/CHECKPOINT.md"; do
		[ -f "$f" ] && [ ! -L "$f" ] && [ -O "$f" ] || continue
		if [ ! -e "$m" ] || [ -n "$(find "$f" -newer "$m" 2>/dev/null)" ]; then
			printf '%s\n' "$m"
			return 0
		fi
	done
	return 1
}

if mark=$(gate); then
	[ -z "$mark" ] || touch "$mark" 2>/dev/null
else
	printf '%s\n' "knackpack: this session has no checkpoint saved since its last compaction, so this /compact was stopped. Run /knackpack:checkpoint, then /compact again, or run /compact skip-checkpoint to compact without one. KNACKPACK_COMPACT_GATE=on turns this check on." >&2
	trap - EXIT
	exit 2
fi

setting=$(printf '%s' "${KNACKPACK_COMPACT:-${EVAL_KNACKPACK_COMPACT:-}}" | tr '[:upper:]' '[:lower:]')
case $setting in off | 0 | false | no) exit 0 ;; esac

cat <<'EOF'
From knackpack: this summary will already quote the developer's messages, but what you found out yourself is what summaries most often drop, so keep that too, with exact values:
- the results of the commands, scripts, tests and searches you ran: the numbers, names, paths and errors they produced;
- each cause you diagnosed, each explanation you gave and each decision you made, with its reason;
- the approaches you tried or rejected, and why;
- every file you created or changed, and where you saved reports, briefs, plans and checkpoints, by absolute path.
Keep how the developer asked the work to be done, word for word, such as who implements it (this session, or subagents it orchestrates) and which skill is driving it, such as execute-plan: a summary that keeps what was built but drops how lets the next context switch to doing the work differently.
If your last reply asked the developer questions or offered numbered options, copy them word for word, with their numbering and the heading they sat under, since the developer may answer with just a number.
If you saved a checkpoint to resume the current task from, such as CHECKPOINT.md, say in the next step to read it in full before continuing, by its absolute path, and that this summary is newer where it covers later work.
EOF
