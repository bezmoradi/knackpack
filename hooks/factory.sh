#!/bin/sh
# Knackpack's software factory page: a self-updating HTML view of every
# Claude Code session on this machine, with its state, the questions Claude
# asked and the answers picked, its intent record, the agents it ran and how
# they ended, and its tasks.
#
#   factory.sh record [tool | detail]
#                       (hooks) append what this event adds to the session's
#                       file and rebuild the page; does nothing until
#                       tracking is turned on. `tool` marks the hooks on
#                       every tool call, which matter only while a session
#                       waits on a permission prompt, and once a minute to
#                       show a long turn is still busy; `detail` marks the
#                       hooks on question dialogs, agent hand-backs and
#                       failed agent calls
#   factory.sh on       turn tracking on, build the page and print its path
#   factory.sh off      turn tracking off, keeping what was recorded
#   factory.sh clear    delete what was recorded, and the page
#   factory.sh status   print whether tracking is on, the page's path and how
#                       many sessions it holds
#
# Nothing talks to Claude. Claude Code runs this script on hook events, the
# script writes files, and the page, opened from disk, reloads itself.
#
# What it stores: event times and kinds, each session's working folder,
# notification and error types, the error message of a failed agent call,
# subagent types and IDs, task titles, the text of questions Claude asked in
# its question dialogs with the answers picked,
# and, for knackpack's own agents, the report path and verdict line they end
# with. Never prompts, tool input, file contents or other messages. At render
# time it also reads the session's intent record, which track-intent keeps in
# the same state folder.
#
# Everything lives in ${XDG_STATE_HOME:-$HOME/.local/state}/knackpack/factory:
# the marker file `enabled`, one file per session in sessions/, a marker per
# session waiting on a permission prompt in waiting/, and
# software-factory.html, built from hooks/factory.html. Files untouched for 7
# days are deleted when a session starts. The script uses no network, never
# touches a repository, and exits 0 on every failure so a problem here never
# blocks a session.
#
# KNACKPACK_FACTORY=off stops recording even when tracking is on.
# KNACKPACK_FACTORY=on also records sessions nobody attends, such as
# `claude -p`, which it skips by default.

# test -O isn't POSIX, but dash and bash both have it.
# shellcheck disable=SC3067
umask 077
trap 'exit 0' EXIT
mode=${1:-}
case $mode in record | on | off | clear | status) ;; *) exit 0 ;; esac

here=$(CDPATH='' cd -- "$(dirname -- "$0")" 2>/dev/null && pwd -P) || exit 0
template=$here/factory.html
base=${XDG_STATE_HOME:-}
[ -n "$base" ] || { [ -n "${HOME:-}" ] && base=$HOME/.local/state; } || exit 0
dir=$base/knackpack/factory
intent=$base/knackpack/intent
sessions=$dir/sessions
waiting=$dir/waiting
page=$dir/software-factory.html
marker=$dir/enabled
keep_days=7
max_sessions=100

# A folder this script writes into must be a real folder owned by this user,
# not a symlink someone could point elsewhere.
ours() { [ -d "$1" ] && [ ! -L "$1" ] && [ -O "$1" ]; }
prepare() {
	mkdir -p "$sessions" "$waiting" 2>/dev/null && ours "$dir" && ours "$sessions" && ours "$waiting" &&
		chmod 700 "$dir" "$sessions" "$waiting" 2>/dev/null
}

# Session file lines: time, kind, working folder, then up to four fields:
#   start <source>       prompt               notify <type>       stop
#   fail <error>         end                  tool (a permission prompt was answered,
#                                             or a busy turn's once-a-minute sign of life)
#   agent+ <id> <type>   agent- <id> <type> <report> <verdict>
#   report <id> <type> <report> <verdict>     agentx <type> <error>
#   task+ <id> <title>   task- <id> <title>   qa <question> <answer>
#
# Rebuild the page from the newest session files and their intent records,
# then swap it in whole, so the browser never reads a half-written page.
# Session IDs are checked when they're recorded, so the names are safe.
render() {
	ours "$dir" && ours "$sessions" && [ -f "$template" ] || return 0
	# The time comes from date, since mawk's srand() gives micro- or
	# nanoseconds where POSIX awk's gives seconds.
	rnow=${now:-$(date +%s 2>/dev/null)}
	case $rnow in '' | *[!0-9]*) return 0 ;; esac
	tmp=$dir/.software-factory.$$.html
	rm -f "$tmp"
	# Newest first needs ls -t, which POSIX has no other way to do; the grep
	# keeps only names the hook itself writes, so odd names can't get through.
	# shellcheck disable=SC2010
	files=$(cd "$sessions" 2>/dev/null && ls -t 2>/dev/null | grep -E '^[A-Za-z0-9-]{1,64}\.tsv$' | head -n "$max_sessions")
	set --
	for f in $files; do
		set -- "$@" kind=s "$sessions/$f"
		sid=${f%.tsv}
		if ours "$intent"; then
			for r in "$intent"/*/"$sid".md "$intent"/*/"$sid".[0-9]*.md; do
				[ -f "$r" ] && [ ! -L "$r" ] && set -- "$@" kind=r "sid=$sid" "$r"
			done
		fi
	done
	# With no files, awk would read stdin instead.
	[ "$#" -gt 0 ] || set -- /dev/null
	LC_ALL=C awk -v tpl="$template" -v now="$rnow" '
	function js(s,    i, n, c, o) {
		o = ""; n = length(s)
		for (i = 1; i <= n; i++) {
			c = substr(s, i, 1)
			if (c == "\\") o = o "\\\\"
			else if (c == "\"") o = o "\\\""
			else if (c == "<") o = o "\\u003c"
			else if (c == ">") o = o "\\u003e"
			else if (c == "&") o = o "\\u0026"
			else if (c < " ") o = o " "
			else o = o c
		}
		return "\"" o "\""
	}
	function sess(sid) {
		if (!(sid in idx)) { n++; idx[sid] = n; id[n] = sid; st[n] = "started"; det[n] = ""; first[n] = ""; nt[n] = 0; na[n] = 0; nq[n] = 0; nr[n] = 0 }
		return idx[sid]
	}
	function newagent(i, aid, type) { na[i]++; ak[i, na[i]] = aid; atype[i, na[i]] = type; ast[i, na[i]] = "running"; abeg[i, na[i]] = $1 + 0; aend[i, na[i]] = 0; aver[i, na[i]] = ""; arep[i, na[i]] = ""; aerr[i, na[i]] = ""; return na[i] }
	function findagent(i, aid,    a) { for (a = na[i]; a >= 1; a--) if (ak[i, a] == aid) return a; return 0 }
	BEGIN { FS = "\t"; n = 0 }
	kind == "s" {
		if (FNR == 1) { sid = FILENAME; sub(/.*\//, "", sid); sub(/\.tsv$/, "", sid); i = sess(sid); first[i] = $2 }
		k = $2; last[i] = $1 + 0
		if (cwd[i] == "" && $3 != "") cwd[i] = $3
		if (k == "start") { st[i] = "ready"; det[i] = "" }
		else if (k == "prompt") { st[i] = "working"; det[i] = "" }
		else if (k == "notify" && $4 == "permission_prompt") { st[i] = "waiting"; det[i] = "needs your permission" }
		else if (k == "notify" && $4 == "idle_prompt") { st[i] = "waiting"; det[i] = "waiting for your reply" }
		else if (k == "tool") { if (st[i] == "waiting") { st[i] = "working"; det[i] = "" } }
		else if (k == "stop") { st[i] = "your turn"; det[i] = "" }
		else if (k == "fail") { st[i] = "failed"; det[i] = $4 }
		else if (k == "end") { st[i] = "ended"; det[i] = "" }
		else if (k == "agent+" && $5 != "") { if (!findagent(i, $4)) newagent(i, $4, $5) }
		else if (k == "agent-" && $5 != "") {
			a = findagent(i, $4); if (!a) { a = newagent(i, $4, $5); abeg[i, a] = $1 + 0 }
			ast[i, a] = "done"; aend[i, a] = $1 + 0
			if ($6 != "") arep[i, a] = $6
			if ($7 != "") aver[i, a] = $7
		}
		else if (k == "report") {
			a = findagent(i, $4); if (!a) a = newagent(i, $4, $5)
			if ($6 != "") arep[i, a] = $6
			if ($7 != "") aver[i, a] = $7
		}
		else if (k == "agentx") {
			for (a = na[i]; a >= 1; a--) if (ast[i, a] == "running" && atype[i, a] == $4) break
			if (a < 1) a = newagent(i, "", ($4 == "" ? "agent" : $4))
			ast[i, a] = "failed"; aend[i, a] = $1 + 0; aerr[i, a] = $5
		}
		else if ((k == "task+" || k == "task-") && $4 != "") {
			if (!((i, $4) in task)) { nt[i]++; tid[i, nt[i]] = $4; task[i, $4] = $5 }
			else if ($5 != "") task[i, $4] = $5
			if (k == "task-") tdone[i, $4] = 1
		}
		else if (k == "qa" && $4 != "") { nq[i]++; qq[i, nq[i]] = $4; qa[i, nq[i]] = $5; qt[i, nq[i]] = $1 + 0 }
		next
	}
	kind == "r" {
		if (FNR == 1) { i = sess(sid); nr[i]++; r = nr[i]; rtitle[i, r] = ""; rn[i, r, "a"] = 0; rn[i, r, "s"] = 0; rn[i, r, "o"] = 0; part = "" }
		if ($0 ~ /^# Intent record: /) { t = $0; sub(/^# Intent record: /, "", t); rtitle[i, r] = t; next }
		if ($0 ~ /^## /) { part = ($0 ~ /^## Agreed/) ? "a" : ($0 ~ /^## Assumed/) ? "s" : ($0 ~ /^## Open questions/) ? "o" : ""; next }
		if (part == "" || $0 !~ /^- [A-Z]+-[0-9]+: /) next
		line = $0; sub(/^- /, "", line); rid = line; sub(/:.*/, "", rid); txt = line; sub(/^[A-Z]+-[0-9]+: /, "", txt)
		# The quote, reason or what an entry blocks shows when its row opens.
		more = ""; if (match(txt, / (Said|Why|Blocks): /)) { more = substr(txt, RSTART + 1); txt = substr(txt, 1, RSTART - 1) }
		rn[i, r, part]++; ri[i, r, part, rn[i, r, part]] = rid; rt[i, r, part, rn[i, r, part]] = txt; rm[i, r, part, rn[i, r, part]] = more
		next
	}
	function rank(s) {
		return s == "waiting" ? 0 : s == "failed" ? 1 : s == "working" ? 2 : s == "your turn" ? 3 : s == "ready" ? 4 : s == "started" ? 5 : 6
	}
	function list(i, r, p,    out, x) {
		out = ""
		for (x = 1; x <= rn[i, r, p]; x++) out = out (x > 1 ? "," : "") "{\"id\":" js(ri[i, r, p, x]) ",\"text\":" js(rt[i, r, p, x]) ",\"more\":" js(rm[i, r, p, x]) "}"
		return "[" out "]"
	}
	END {
		m = 0
		for (i = 1; i <= n; i++) if (last[i] > 0) { m++; ord[m] = i; key[i] = rank(st[i]) * 1e11 + (1e11 - last[i]) }
		for (x = 2; x <= m; x++) { y = x; while (y > 1 && key[ord[y - 1]] > key[ord[y]]) { t = ord[y]; ord[y] = ord[y - 1]; ord[y - 1] = t; y-- } }
		json = "{\"generated\":" now ",\"sessions\":["
		for (x = 1; x <= m; x++) {
			i = ord[x]
			s = "{\"id\":" js(id[i]) ",\"cwd\":" js(cwd[i]) ",\"state\":" js(st[i]) ",\"detail\":" js(det[i]) ",\"last\":" last[i] \
				",\"beforeTracking\":" (first[i] != "start" ? "true" : "false") ",\"tasks\":["
			for (t = 1; t <= nt[i]; t++) s = s (t > 1 ? "," : "") "{\"subject\":" js(task[i, tid[i, t]]) ",\"done\":" (((i, tid[i, t]) in tdone) ? "true" : "false") "}"
			s = s "],\"agents\":["
			for (a = 1; a <= na[i]; a++)
				s = s (a > 1 ? "," : "") "{\"id\":" js(ak[i, a]) ",\"type\":" js(atype[i, a]) ",\"state\":" js(ast[i, a]) ",\"start\":" abeg[i, a] ",\"end\":" aend[i, a] \
					",\"verdict\":" js(aver[i, a]) ",\"report\":" js(arep[i, a]) ",\"error\":" js(aerr[i, a]) ",\"knackpack\":" (atype[i, a] ~ /^knackpack:/ ? "true" : "false") "}"
			s = s "],\"questions\":["
			for (q = 1; q <= nq[i]; q++) s = s (q > 1 ? "," : "") "{\"q\":" js(qq[i, q]) ",\"a\":" js(qa[i, q]) ",\"ts\":" qt[i, q] "}"
			s = s "],\"records\":["
			for (r = 1; r <= nr[i]; r++) s = s (r > 1 ? "," : "") "{\"title\":" js(rtitle[i, r]) ",\"agreed\":" list(i, r, "a") ",\"assumed\":" list(i, r, "s") ",\"open\":" list(i, r, "o") "}"
			json = json (x > 1 ? "," : "") s "]}"
		}
		json = json "]}"
		while ((getline line < tpl) > 0) {
			if (line == "<!-- knackpack:data -->") print "<script id=\"data\" type=\"application/json\">" json "</script>"
			else print line
		}
		close(tpl)
	}' "$@" >"$tmp" 2>/dev/null && grep -q 'id="data"' "$tmp" && mv -f "$tmp" "$page" 2>/dev/null
	rm -f "$tmp" 2>/dev/null
	return 0
}

case $mode in
on)
	prepare || { printf '%s\n' "Couldn't create $dir as a private folder of yours."; exit 0; }
	: >"$marker" 2>/dev/null
	render
	printf '%s\n' "Software factory is on. Sessions appear from their next event. Page: $page"
	;;
off)
	rm -f "$marker" 2>/dev/null
	printf '%s\n' "Software factory is off. What was recorded stays until you clear it. Page: $page"
	;;
clear)
	ours "$sessions" && find "$sessions" -type f -name '*.tsv' -exec rm -f {} + 2>/dev/null
	ours "$waiting" && find "$waiting" -type f -exec rm -f {} + 2>/dev/null
	rm -f "$page" 2>/dev/null
	[ -f "$marker" ] && render
	printf '%s\n' "Cleared what the software factory recorded."
	;;
status)
	if [ -f "$marker" ]; then s=on; else s=off; fi
	count=0
	ours "$sessions" && count=$(find "$sessions" -type f -name '*.tsv' 2>/dev/null | wc -l | tr -d ' ')
	printf '%s\n' "Software factory is $s; $count session file(s) recorded. Page: $page"
	;;
record)
	# Silent: anything printed here would reach Claude's context.
	exec >/dev/null 2>&1
	[ -f "$marker" ] || exit 0
	setting=$(printf '%s' "${KNACKPACK_FACTORY:-}" | tr '[:upper:]' '[:lower:]')
	case $setting in
	off | 0 | false | no) exit 0 ;;
	on | 1 | true | yes) ;;
	*)
		# The same test as track-intent.sh: Claude Code 2.1.310 sets both for
		# hooks, 1 and cli in an attended session, 0 and sdk-cli under
		# `claude -p`. Neither is documented, so a missing value counts as
		# attended.
		if [ -n "${CLAUDE_CODE_SESSION_ATTENDED:-}" ]; then
			[ "$CLAUDE_CODE_SESSION_ATTENDED" = 0 ] && exit 0
		else
			case ${CLAUDE_CODE_ENTRYPOINT:-} in sdk-*) exit 0 ;; esac
		fi
		;;
	esac
	prepare || exit 0
	now=$(date +%s 2>/dev/null)
	case $now in '' | *[!0-9]*) exit 0 ;; esac
	if [ "${2:-}" = tool ]; then
		# Tool calls are the most frequent event, and one needs only the
		# session ID, from the first few kilobytes. It shows that this
		# session's permission prompt was answered, or else that the session
		# is still busy, which the page needs at most once a minute so a long
		# turn doesn't look quiet. The awk prints the session ID and the time
		# of its file's last line; a session with no file gets nothing.
		out=$(head -c 4096 | LC_ALL=C awk -v dir="$sessions" '
		{ s = s $0 }
		END {
			if (!match(s, /"session_id"[ \t]*:[ \t]*"[A-Za-z0-9-]+"/)) exit
			v = substr(s, RSTART, RLENGTH); sub(/^"session_id"[ \t]*:[ \t]*"/, "", v); sub(/"$/, "", v)
			f = dir "/" v ".tsv"; t = 0
			while ((getline l < f) > 0) { split(l, a, "\t"); if (a[1] + 0 > 0) t = a[1] + 0 }
			print v " " t
		}')
		sid=${out% *} last=${out#* }
		case $sid in '' | *[!A-Za-z0-9-]*) exit 0 ;; esac
		[ "${#sid}" -le 64 ] || exit 0
		case $last in '' | *[!0-9]*) exit 0 ;; esac
		file=$sessions/$sid.tsv
		[ -f "$file" ] && [ ! -L "$file" ] || exit 0
		if [ -f "$waiting/$sid" ]; then
			rm -f "$waiting/$sid" 2>/dev/null
		else
			[ "$last" -gt 0 ] && [ $((now - last)) -ge 60 ] || exit 0
		fi
		printf '%s\ttool\t\n' "$now" >>"$file" || exit 0
		render
		exit 0
	fi
	# The first line out is the session ID, the event and the notification
	# type, for the decisions below; the rest are the lines to append. JSON
	# strings are decoded for the common escapes, with \u escapes as "?", and
	# every stored value is capped at 300 bytes, cut at a word and marked.
	out=$(head -c 1048576 | tr '\n\r' '  ' | LC_ALL=C awk -v now="$now" '
	function decode(s, i, keepnl,    n, c, o) {
		o = ""; n = length(s)
		while (i <= n) {
			c = substr(s, i, 1)
			if (c == "\"") { end_at = i; return o }
			if (c == "\\") {
				i++; c = substr(s, i, 1)
				if (c == "u") { o = o "?"; i += 4 }
				else if (c == "n" && keepnl) o = o "\n"
				else if (c == "n" || c == "t" || c == "r" || c == "b" || c == "f") o = o " "
				else o = o c
			} else o = o c
			i++
		}
		end_at = n; return o
	}
	function clean(s,    t) {
		gsub(/[\001-\037\177]/, " ", s); gsub(/  +/, " ", s); sub(/^ /, "", s); sub(/ $/, "", s)
		# Mark a cut, so the page never shows a clipped word as if it were
		# whole. The cut drops the last UTF-8 character, which may be partial,
		# and goes back to a space if one is near; text without spaces, such
		# as Chinese or Japanese, is cut between characters.
		if (length(s) > 300) {
			s = substr(s, 1, 297); sub(/[\300-\377][\200-\277]*$/, "", s)
			t = s; sub(/ [^ ]*$/, "", t); if (t != s && length(s) - length(t) <= 40) s = t
			s = s "..."
		}
		return s
	}
	# The first string value of a key, searching from position `from`.
	function jstr(s, key, from,    t) {
		if (from < 1) return ""
		t = substr(s, from)
		if (!match(t, "\"" key "\"[ \t]*:[ \t]*\"")) return ""
		return clean(decode(s, from + RSTART + RLENGTH - 1))
	}
	# The same with line breaks kept and nothing cut, for report() to read.
	function jraw(s, key, from,    t) {
		if (from < 1) return ""
		t = substr(s, from)
		if (!match(t, "\"" key "\"[ \t]*:[ \t]*\"")) return ""
		return decode(s, from + RSTART + RLENGTH - 1, 1)
	}
	function at(s, key) { return match(s, "\"" key "\"[ \t]*:") ? RSTART : 0 }
	# A knackpack agent ends with its report path and a verdict line; keep
	# only those, and nothing from any other agent. The verdict is the first
	# line that names one, or else the first line with more than a heading
	# mark: an agent that could not save its report replies with all of it.
	function report(msg, type,    n, x, l, pick, first, parts) {
		rpath = ""; rverdict = ""
		if (type !~ /^knackpack:/ || msg == "") return
		if (match(msg, /\/[^ \t\n"`<>()\[\]*]*\.md/)) { rpath = substr(msg, RSTART, RLENGTH); msg = substr(msg, 1, RSTART - 1) " " substr(msg, RSTART + RLENGTH) }
		n = split(msg, parts, "\n"); pick = ""; first = ""; under = 0
		for (x = 1; x <= n && x <= 40; x++) {
			# Drop Markdown emphasis and code marks and a leading quote, list or
			# heading mark, but keep comparisons such as "pct > 1".
			l = parts[x]; gsub(/[`*]/, "", l); l = clean(l); sub(/^[#>-]+ */, "", l)
			if (l == "") continue
			# A bare "Verdict" heading: the verdict is the line under it.
			if (tolower(l) ~ /^(verdict|recommendation)[: ]*$/) { under = 1; continue }
			if (under || tolower(l) ~ /verdict|recommend|established|refuted|changes required|no blocking/) { pick = l; break }
			if (first == "") first = l
		}
		rverdict = pick != "" ? pick : first
	}
	function line(k, a, b, c, d) { lines = lines now "\t" k "\t" cwd "\t" a "\t" b "\t" c "\t" d "\n" }
	{ s = s $0 }
	END {
		lines = ""
		ev = jstr(s, "hook_event_name", 1); sid = jstr(s, "session_id", 1); cwd = jstr(s, "cwd", 1)
		nt = jstr(s, "notification_type", 1); tool = jstr(s, "tool_name", 1)
		if (ev == "SessionStart") line("start", jstr(s, "source", 1))
		else if (ev == "UserPromptSubmit") line("prompt")
		else if (ev == "Notification") line("notify", nt)
		else if (ev == "Stop") line("stop")
		else if (ev == "StopFailure") line("fail", jstr(s, "error", 1))
		else if (ev == "SessionEnd") line("end")
		# Claude Code also runs internal agents with no type; leave them out.
		else if (ev == "SubagentStart") { ty = jstr(s, "agent_type", 1); if (ty != "") line("agent+", jstr(s, "agent_id", 1), ty) }
		else if (ev == "SubagentStop") {
			ty = jstr(s, "agent_type", 1); report(jraw(s, "last_assistant_message", 1), ty)
			if (ty != "") line("agent-", jstr(s, "agent_id", 1), ty, rpath, rverdict)
		}
		else if (ev == "TaskCreated") line("task+", jstr(s, "task_id", 1), jstr(s, "task_subject", 1))
		else if (ev == "TaskCompleted") line("task-", jstr(s, "task_id", 1), jstr(s, "task_subject", 1))
		else if (ev == "PostToolUse" || ev == "PostToolUseFailure") {
			if (ev == "PostToolUse" && tool == "AskUserQuestion") {
				# Pair each answer with its question from tool_response.answers,
				# an object of question text to the picked labels.
				p = at(s, "tool_response")
				if (p) { q = at(substr(s, p), "answers"); p = q ? p + q - 1 : 0 }
				if (p && match(substr(s, p), /"answers"[ \t]*:[ \t]*\{/)) {
					i = p + RSTART + RLENGTH - 1; n = length(s)
					while (i <= n) {
						c = substr(s, i, 1)
						if (c == "}") break
						if (c == "\"") {
							k = clean(decode(s, i + 1)); i = end_at + 1
							while (i <= n && substr(s, i, 1) != "\"" && substr(s, i, 1) != "}") i++
							if (substr(s, i, 1) != "\"") break
							v = clean(decode(s, i + 1)); i = end_at + 1
							line("qa", k, v)
						} else i++
					}
				}
			}
			# From Claude Code 2.1.271, a subagent in auto mode delivers its
			# report through the SubagentHandback tool, as tool_input.message,
			# and SubagentStop then carries only its closing text (hooks
			# reference, SubagentStop and the Agent tool result).
			else if (ev == "PostToolUse" && tool == "SubagentHandback") {
				ty = jstr(s, "agent_type", 1); report(jraw(s, "message", at(s, "tool_input")), ty)
				if (ty ~ /^knackpack:/) line("report", jstr(s, "agent_id", 1), ty, rpath, rverdict)
			}
			else if (ev == "PostToolUseFailure" && (tool == "Agent" || tool == "Task"))
				line("agentx", jstr(s, "subagent_type", at(s, "tool_input")), jstr(s, "error", 1))
		}
		printf "%s\t%s\t%s\n%s", sid, ev, nt, lines
	}')
	head=$(printf '%s\n' "$out" | sed -n 1p)
	sid=$(printf '%s\n' "$head" | awk -F '\t' '{ print $1 }')
	event=$(printf '%s\n' "$head" | awk -F '\t' '{ print $2 }')
	ntype=$(printf '%s\n' "$head" | awk -F '\t' '{ print $3 }')
	case $sid in '' | *[!A-Za-z0-9-]*) exit 0 ;; esac
	[ "${#sid}" -le 64 ] || exit 0
	file=$sessions/$sid.tsv
	[ -L "$file" ] && exit 0
	body=$(printf '%s\n' "$out" | sed 1d)
	[ -n "$body" ] || exit 0
	if [ "$event" = SessionStart ] && printf '%s\n' "$body" | awk -F '\t' '$2 == "start" && $4 == "startup" { f = 1 } END { exit !f }'; then
		find "$sessions" -type f -name '*.tsv' -mtime +"$keep_days" -exec rm -f {} + 2>/dev/null
		find "$waiting" -type f -mtime +"$keep_days" -exec rm -f {} + 2>/dev/null
	fi
	printf '%s\n' "$body" >>"$file" || exit 0
	if [ "$event" = Notification ] && [ "$ntype" = permission_prompt ]; then
		: >"$waiting/$sid"
	elif [ "${2:-}" != detail ]; then
		rm -f "$waiting/$sid" 2>/dev/null
	fi
	render
	;;
esac
