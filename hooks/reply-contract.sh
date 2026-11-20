#!/bin/sh
# PreToolUse hook on SubagentHandback, and SubagentStop hook: check the two
# machine-readable lines a knackpack agent's reply ends with, and send the
# agent back once to fix them when they're missing or malformed, so a program
# that reads them, such as a push gate, gets valid lines or none.
#
# Every knackpack agent's reply ends with `knackpack-verdict/1: pass` or
# `knackpack-verdict/1: block`, with nothing after it, and every one but the
# adjudicator has `knackpack-findings/1: critical=N high=N medium=N low=N
# blocking=N` just before it, where a blocking count above 0 never comes with
# pass (scripts/review-protocol.md, and the README's "Reading knackpack from a
# tool"). This hook checks only those two lines; the finding and coverage lines
# above them are informational, and programs drop a malformed one themselves.
#
# Claude Code delivers a subagent's reply in one of two ways. In auto mode,
# since 2.1.271, the subagent hands it back through the SubagentHandback tool,
# whose PreToolUse input holds it as tool_input.message; denying the call
# makes the subagent call it again, and Claude Code allows three denials. That
# path has no flag saying a call follows a denial, so the hook keeps one empty
# marker per agent ID in its own state folder,
# ${XDG_STATE_HOME:-$HOME/.local/state}/knackpack/reply-check, creates the
# folder, deletes markers untouched for 30 days, and denies a hand-back only
# while its agent has no marker. Without the folder it lets every hand-back
# through. In other modes the reply is SubagentStop's last_assistant_message,
# and returning additionalContext keeps the subagent working; the next
# SubagentStop then has stop_hook_active true, and the hook lets it stop. In
# auto mode, SubagentStop's message is the subagent's closing text rather
# than its reply, so the hook leaves SubagentStop alone there.
#
# It acts only for agents named knackpack:<name>. It writes nothing but its
# markers, reads nothing but its input and, on SubagentStop, the subagent's
# transcript, uses no network, and exits 0 on every failure, printing nothing
# whenever it can't tell, so a problem here never holds a reply back. It runs
# in headless sessions too, where programs read the lines most.
# KNACKPACK_REPLY_CHECK=off turns it off; `claude plugin eval` passes a case
# only variables named EVAL_*, so EVAL_KNACKPACK_REPLY_CHECK stands in for it
# there.

# test -O isn't POSIX, but dash and bash both have it. Before the first
# command, this directive covers the whole script.
# shellcheck disable=SC3067
umask 077
trap 'exit 0' EXIT

setting=$(printf '%s' "${KNACKPACK_REPLY_CHECK:-${EVAL_KNACKPACK_REPLY_CHECK:-}}" | tr '[:upper:]' '[:lower:]')
case $setting in off | 0 | false | no) exit 0 ;; esac

# Reads the event's JSON with a small parser of its own, since jq isn't
# everywhere and a pattern match could read a field's name inside a string,
# such as a reply that quotes one. It prints nothing when the event isn't one
# to check or anything doesn't parse, "ok" for a reply whose lines are fine,
# and otherwise one line: the event, the agent ID, the transcript path and
# the message for the agent, escaped for JSON, separated by tabs. Bytes, not
# characters, so a reply in any encoding parses the same under every awk.
result=$(LC_ALL=C awk '
function fail() { bad = 1; i = n + 1 }
function ws() { while (i <= n && index(" \t\r\n", substr(buf, i, 1))) i++ }
# The JSON string that starts at i, decoded into lines in A, with i moved
# past it; returns the number of lines. A \u escape outside ASCII becomes "?",
# which no line this hook accepts holds. A string with no escape takes one
# index(); one with escapes is split at its backslashes once, since stepping
# through a long reply a character at a time is slow in some awks.
function jstr(A,   rest, q, b, np, P, k, p, e, h, v, j, c, cur, used) {
	split("", A)
	rest = substr(buf, i + 1)
	q = index(rest, "\""); b = index(rest, "\\")
	if (q && (!b || q < b)) { A[1] = substr(rest, 1, q - 1); i += q + 1; return 1 }
	np = split(rest, P, /\\/)
	c = 0; cur = ""; used = 0
	for (k = 1; k <= np; k++) {
		p = P[k]
		if (k > 1) {
			used++
			if (p == "") {
				if (k == np) break
				cur = cur "\\"; used++; p = P[++k]
			} else {
				e = substr(p, 1, 1)
				if (e == "u") {
					h = tolower(substr(p, 2, 4))
					if (h !~ /^[0-9a-f][0-9a-f][0-9a-f][0-9a-f]$/) break
					v = 0
					for (j = 1; j <= 4; j++) v = v * 16 + index("0123456789abcdef", substr(h, j, 1)) - 1
					if (v == 10) { A[++c] = cur; cur = "" }
					else cur = cur (v >= 32 && v < 127 ? sprintf("%c", v) : v == 9 ? "\t" : "?")
					p = substr(p, 6); used += 5
				} else {
					if (e == "n") { A[++c] = cur; cur = "" }
					else if (e == "t") cur = cur "\t"
					else if (e == "r") cur = cur "\r"
					else if (e == "b" || e == "f") cur = cur " "
					else if (e == "\"" || e == "\\" || e == "/") cur = cur e
					else break
					p = substr(p, 2); used++
				}
			}
		}
		q = index(p, "\"")
		if (q) { A[++c] = cur substr(p, 1, q - 1); i += used + q + 1; return c }
		cur = cur p; used += length(p)
	}
	fail(); return 0
}
function str(   m, x, s) {
	m = jstr(T); s = T[1]
	for (x = 2; x <= m; x++) s = s "\n" T[x]
	return s
}
function clean(s, max,   out, k, c) {
	out = ""
	for (k = 1; k <= length(s) && k <= max; k++) {
		c = substr(s, k, 1)
		if (c < " " || c > "~") c = "?"
		out = out c
	}
	if (length(s) > max) out = out "..."
	return out
}
{ buf = buf $0 "\n" }
END {
	n = length(buf); i = 1; d = 0; ws()
	if (substr(buf, i, 1) != "{") exit
	while (i <= n && !bad) {
		ws(); c = substr(buf, i, 1)
		if (c == "") break
		if (c == "{" || c == "[") { d++; ty[d] = c; ek[d] = (c == "{"); key[d] = ""; i++; continue }
		if (c == "}" || c == "]") { if (d < 1) { fail(); break }; d--; i++; if (d == 0) { ws(); if (i <= n) fail(); break }; continue }
		if (c == ":") { ek[d] = 0; i++; continue }
		if (c == ",") { ek[d] = (ty[d] == "{"); i++; continue }
		if (c == "\"") {
			if (ty[d] == "{" && ek[d]) key[d] = str()
			else if (d == 1 && key[1] == "last_assistant_message") nm = jstr(ML)
			else if (d == 2 && ty[1] == "{" && ty[2] == "{" && key[1] == "tool_input" && key[2] == "message") nt = jstr(TL)
			else if (d == 1) f[key[1]] = str()
			else str()
			continue
		}
		st = i
		while (i <= n && substr(buf, i, 1) ~ /[A-Za-z0-9.+-]/) i++
		if (i == st) { fail(); break }
		if (d == 1) f[key[1]] = substr(buf, st, i - st)
	}
	if (bad || d != 0) exit
	ev = f["hook_event_name"]; at = f["agent_type"]; id = f["agent_id"]
	if (substr(at, 1, 10) != "knackpack:" || id !~ /^[A-Za-z0-9-]+$/ || length(id) > 64) exit
	if (ev == "PreToolUse") {
		if (f["tool_name"] != "SubagentHandback" || !nt) exit
		nl = nt; for (k = 1; k <= nl; k++) L[k] = TL[k]
	} else if (ev == "SubagentStop") {
		if (f["stop_hook_active"] != "false" || f["permission_mode"] == "auto" || !nm) exit
		nl = nm; for (k = 1; k <= nl; k++) L[k] = ML[k]
	} else exit
	adj = (at == "knackpack:adjudicator")
	while (nl > 0 && L[nl] ~ /^[ \t\r]*$/) nl--
	V = "^knackpack-verdict/1: (pass|block)$"
	F = "^knackpack-findings/1: critical=[0-9]+ high=[0-9]+ medium=[0-9]+ low=[0-9]+ blocking=[0-9]+$"
	want = adj ? "a last line reading exactly knackpack-verdict/1: pass or knackpack-verdict/1: block" \
		: "a knackpack-findings/1: critical=N high=N medium=N low=N blocking=N line and then a last line reading exactly knackpack-verdict/1: pass or knackpack-verdict/1: block"
	p = ""
	vi = 0
	for (k = nl; k >= 1; k--) if (index(L[k], "knackpack-verdict/1")) { vi = k; break }
	if (!vi) p = "it has no knackpack-verdict/1 line"
	else if (vi < nl && L[vi] ~ V) p = "its knackpack-verdict/1 line isn'"'"'t its last line: the reply ends with \"" clean(L[nl], 100) "\", and nothing may follow the verdict line"
	else if (vi < nl) p = "its knackpack-verdict/1 line, \"" clean(L[vi], 100) "\", isn'"'"'t exactly knackpack-verdict/1: pass or knackpack-verdict/1: block, and it isn'"'"'t the last line"
	else if (L[vi] !~ V) p = "its last line, \"" clean(L[vi], 100) "\", isn'"'"'t exactly knackpack-verdict/1: pass or knackpack-verdict/1: block"
	if (!adj && vi) {
		xi = 0
		for (k = vi - 1; k >= 1; k--) if (index(L[k], "knackpack-findings/1")) { xi = k; break }
		q = ""
		if (!xi) q = "it has no knackpack-findings/1 line"
		else if (L[xi] !~ F) q = "its knackpack-findings/1 line, \"" clean(L[xi], 120) "\", doesn'"'"'t read knackpack-findings/1: critical=N high=N medium=N low=N blocking=N with a number for each N"
		else if (xi != vi - 1) q = "its knackpack-findings/1 line isn'"'"'t the line just before the verdict line"
		else if (p == "" && L[vi] ~ /: pass$/ && L[xi] !~ / blocking=0+$/) q = "it ends with knackpack-verdict/1: pass though its findings line counts blocking findings, and a reply with blocking above 0 ends with knackpack-verdict/1: block"
		if (q != "") p = (p == "" ? q : p "; and " q)
	}
	if (p == "") { print "ok"; exit }
	r = "knackpack reply-format check, from a hook in the knackpack plugin: this reply wasn'"'"'t delivered, because " p ". Your review protocol says your reply ends with " want ", with nothing after it. " (adj ? "Fix only that line, as it says" : "Add or fix only those lines as it says: run its count command on your report file and copy the lines it prints, or, if you can'"'"'t run it, write them yourself from the report in the form it gives") ", keep the rest of your reply as it was, and give the whole reply again. This check sends a reply back once; the next one is delivered as it is."
	tp = f["agent_transcript_path"]
	if (tp !~ /^\/[ -~]*$/ || index(tp, "\t")) tp = ""
	# The message is printable ASCII, since clean() made the quoted lines so,
	# so escaping backslashes and quotes makes it a JSON string.
	gsub(/\\/, "\\\\", r); gsub(/"/, "\\\"", r)
	printf "%s\t%s\t%s\t%s\n", ev, id, tp, r
}' 2>/dev/null) || exit 0

case $result in PreToolUse"	"* | SubagentStop"	"*) ;; *) exit 0 ;; esac
ev=${result%%"	"*}
rest=${result#*"	"}
id=${rest%%"	"*}
rest=${rest#*"	"}
transcript=${rest%%"	"*}
reason=${rest#*"	"}

if [ "$ev" = SubagentStop ]; then
	# A subagent that handed its reply back with the tool ends with closing
	# text that isn't the reply; the hand-back path has checked the reply.
	if [ -n "$transcript" ] && [ -f "$transcript" ] && grep -qF '"name":"SubagentHandback"' "$transcript" 2>/dev/null; then exit 0; fi
	printf '{"hookSpecificOutput":{"hookEventName":"SubagentStop","additionalContext":"%s"}}\n' "$reason"
	exit 0
fi

# PreToolUse: one denial per agent, kept as a marker in a folder this hook
# owns. Any doubt lets the hand-back through.
base=${XDG_STATE_HOME:-}
case $base in /*) ;; *) base=${HOME:-}/.local/state ;; esac
case $base in /*) ;; *) exit 0 ;; esac
dir=$base/knackpack/reply-check
if [ ! -d "$dir" ]; then mkdir -p "$dir" 2>/dev/null || exit 0; fi
[ -d "$dir" ] && [ ! -L "$dir" ] && [ -O "$dir" ] || exit 0
chmod 700 "$dir" 2>/dev/null || exit 0
# Markers of agents left untouched for 30 days.
find "$dir" -type f -mtime +30 -exec rm -f {} + 2>/dev/null
m=$dir/$id
[ ! -e "$m" ] && [ ! -L "$m" ] || exit 0
: >"$m" 2>/dev/null || exit 0
[ -f "$m" ] && [ ! -L "$m" ] && [ -O "$m" ] || exit 0
printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$reason"
exit 0
