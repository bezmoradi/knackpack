#!/bin/sh
# UserPromptSubmit hook: warn when the conversation's context grows large, so
# the developer can save a checkpoint and compact before reasoning degrades.
# Past 400,000 tokens it shows the developer a warning and asks Claude to
# suggest /knackpack:checkpoint, then /compact, once; past 500,000 it asks
# Claude to stop and ask for both before doing more work. It never blocks a
# message: Claude Code also delivers background agents' reports and scheduled
# prompts through this event, and a block would hold those back.
#
# The thresholds are fixed token counts, not a share of the context window,
# because neither the hook's input nor the transcript records the window's
# size; only the status line gets it. On a 200,000-token window they never
# fire, and Claude Code's own auto-compaction applies there.
#
# It estimates the context from the last main-conversation API response in the
# transcript: input tokens, cache reads and writes, and output, which the next
# request carries. The transcript's format isn't documented, and Claude Code
# writes it asynchronously, so the figure can trail by one response; when the
# last response predates a compaction, or nothing parses, it prints nothing.
#
# It reads the event on stdin and the transcript it names, writes nothing, uses
# no network, and exits 0 on every failure so a problem here never blocks a
# session. KNACKPACK_CONTEXT=off turns it off; KNACKPACK_CONTEXT=on also runs
# it in sessions nobody attends, such as `claude -p`, which it skips by default.

umask 077
trap 'exit 0' EXIT

warn_at=400000
stop_at=500000

setting=$(printf '%s' "${KNACKPACK_CONTEXT:-}" | tr '[:upper:]' '[:lower:]')
case $setting in
off | 0 | false | no) exit 0 ;;
on | 1 | true | yes) ;;
*)
	# The same test as track-intent.sh: a background session started with
	# `claude --bg` (cli and 0) runs the hook, `claude -p` (sdk-cli and 0)
	# doesn't, and the attended flag decides only when the entry point is
	# the Agent SDK's or missing.
	case ${CLAUDE_CODE_ENTRYPOINT:-} in
	sdk-*) [ "${CLAUDE_CODE_SESSION_ATTENDED:-}" = 1 ] || exit 0 ;;
	'') [ "${CLAUDE_CODE_SESSION_ATTENDED:-}" = 0 ] && exit 0 ;;
	esac
	;;
esac

input=$(head -c 65536)
# Prints the first value of a string field in the event, as track-intent.sh
# does: the event's own fields come before anything nested.
field() {
	printf '%s\n' "$input" | awk -v k="$1" '
	match($0, "\"" k "\"[ \t]*:[ \t]*\"[^\"]*\"") {
		s = substr($0, RSTART, RLENGTH)
		sub(/^"[^"]*"[ \t]*:[ \t]*"/, "", s)
		print substr(s, 1, length(s) - 1)
		exit
	}'
}

# The checkpoint and compaction the warning asks for go ahead without it.
case $(field prompt) in /knackpack:checkpoint* | /compact*) exit 0 ;; esac

transcript=$(field transcript_path)
case $transcript in /*.jsonl) ;; *) exit 0 ;; esac
[ -f "$transcript" ] && [ ! -L "$transcript" ] || exit 0

# The last 2 MB hold the last response unless a tool result after it is larger,
# which leaves nothing to parse and so prints nothing; reading more costs time
# on every message.
tokens=$(tail -c 2000000 "$transcript" 2>/dev/null | grep -E '"usage"|"compact_boundary"' 2>/dev/null | awk '
	function num(line, key,    s) {
		if (!match(line, "\"" key "\"[ \t]*:[ \t]*[0-9]+")) return 0
		s = substr(line, RSTART, RLENGTH)
		sub(/^.*:[ \t]*/, "", s)
		return s + 0
	}
	/"subtype"[ \t]*:[ \t]*"compact_boundary"/ { last = 0; next }
	/"isSidechain"[ \t]*:[ \t]*false/ && /"type"[ \t]*:[ \t]*"assistant"/ && /"usage"[ \t]*:/ {
		u = $0
		sub(/^.*"usage"[ \t]*:[ \t]*\{/, "", u)
		last = num(u, "input_tokens") + num(u, "cache_creation_input_tokens") + num(u, "cache_read_input_tokens") + num(u, "output_tokens")
	}
	END { if (last > 0) print last }' 2>/dev/null)
case $tokens in '' | *[!0-9]*) exit 0 ;; esac
[ "$tokens" -ge "$warn_at" ] || exit 0
k=$((tokens / 1000))

if [ "$tokens" -ge "$stop_at" ]; then
	user="knackpack: this conversation holds about ${k}k tokens, past the 500k limit. Run /knackpack:checkpoint, then /compact, before continuing."
	claude="knackpack context check: the conversation holds about ${k}k tokens, past the 500,000 at which knackpack asks to compact, because reasoning over a context this long gets less reliable. Unless this message asks for a checkpoint or compaction, or the developer has already said in this conversation to carry on without compacting, don't start new work on it: say the context is too long and ask them to run /knackpack:checkpoint, then /compact, and to resend the message. If they've said to carry on, do so and mention the context size in one line."
else
	user="knackpack: this conversation holds about ${k}k tokens. At a good stopping point, run /knackpack:checkpoint, then /compact; past 500k, Claude will ask you to."
	claude="knackpack context check: the conversation holds about ${k}k tokens, past the 400,000 at which knackpack suggests compacting, because reasoning over a long context gets less reliable. Carry on with this message. If you haven't yet told the developer since the context passed 400,000 tokens, end your reply with one line suggesting /knackpack:checkpoint, then /compact, at a good stopping point."
fi
# Fixed text and a number, so nothing here needs JSON escaping.
printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"%s"}}\n' "$user" "$claude"
