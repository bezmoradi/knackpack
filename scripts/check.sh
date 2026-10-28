#!/bin/sh
# Runs knackpack's pre-publish checks: the rules in .claude/CLAUDE.md that a
# script can check. Prints one line per check and exits 1 if any fails.
# Needs git, dash and the claude CLI; bash is used too when installed.
#
#   sh scripts/check.sh
#
# It doesn't check for misspelled frontmatter keys; see "Before you publish"
# in .claude/CLAUDE.md for that.

cd "$(dirname -- "$0")/.." || exit 1
failed=0
pass() { printf 'ok    %s\n' "$1"; }
fail() {
	printf 'FAIL  %s\n' "$1"
	failed=1
}
# Counts the UTF-8 characters on stdin: every byte except continuation bytes.
chars() { LC_ALL=C tr -d '\200-\277' | wc -c | tr -d ' '; }
body() { awk 'n >= 2 { print; next } /^---[[:space:]]*$/ { n++ }' "$1"; }
frontmatter() { awk '/^---[[:space:]]*$/ { if (++n == 2) exit; next } n == 1' "$1"; }

tmp=$(mktemp -d "${TMPDIR:-/tmp}/knackpack-check.XXXXXX") || exit 1
trap 'rm -rf "$tmp"' EXIT

# Validation, with no warning but the missing icon.
if ! command -v claude >/dev/null 2>&1; then
	fail "claude plugin validate: the claude CLI isn't installed"
elif ! claude plugin validate . >"$tmp/validate" 2>&1; then
	fail "claude plugin validate failed:"
	cat "$tmp/validate"
else
	# Only the missing icon may warn, and it doesn't change the result line.
	other=$(grep -o '([A-Z][A-Z_]*)' "$tmp/validate" | grep -v '^(ICON_MISSING)$' | sort -u | tr '\n' ' ')
	if [ -n "$other" ] || ! grep -qx '✔ Validation passed' "$tmp/validate"; then
		fail "claude plugin validate warned:"
		cat "$tmp/validate"
	else
		pass "claude plugin validate"
	fi
fi

# Nothing at the root that would ship to every user unasked.
for f in .mcp.json bin settings.json; do
	[ -e "$f" ] && fail "$f exists at the root"
done

# The agents: report-only, no CLAUDE.md, and one shared review protocol.
# Claude Code splits tools on commas and on spaces outside parentheses. What's
# in parentheses doesn't narrow Agent in a subagent, so it's dropped, and Task
# is the Agent tool's old name.
tool_is() { printf '%s\n' "$tools" | sed 's/([^)]*)//g' | tr ', \t' '\n\n\n' | grep -Ex "$1" >/dev/null; }
agents_ok=1
n=0
for f in agents/*.md; do
	n=$((n + 1))
	name=${f#agents/}
	name=${name%.md}
	frontmatter "$f" >"$tmp/fm"
	tools=$(sed -n 's/^tools:[[:space:]]*//p' "$tmp/fm")
	[ -n "$tools" ] || { fail "$name has no tools: list"; agents_ok=0; }
	case $tools in *\[* | *\]* | *\"* | *\'*)
		fail "$name: write tools: as a plain comma-separated list, which this check can read"
		agents_ok=0
		;;
	esac
	tool_is 'Edit|Write|NotebookEdit|MultiEdit' && { fail "$name has a file-editing tool"; agents_ok=0; }
	if tool_is 'Agent|Task'; then
		case $name in adversarial-reviewer | asvs-security-reviewer | architecture-reviewer) ;; *) fail "$name has the Agent tool"; agents_ok=0 ;; esac
	fi
	grep -qx 'omitClaudeMd: true' "$tmp/fm" || { fail "$name lacks omitClaudeMd: true"; agents_ok=0; }
	sed -n '/^## Review protocol$/,$p' "$f" >"$tmp/protocol"
	[ -s "$tmp/protocol" ] || { fail "$name has no Review protocol section"; agents_ok=0; }
	cksum <"$tmp/protocol" >>"$tmp/sums"
done
[ "$n" = 6 ] || { fail "expected 6 agents, found $n"; agents_ok=0; }
[ "$(sort -u "$tmp/sums" | wc -l | tr -d ' ')" = 1 ] || { fail "the review protocol differs between agents"; agents_ok=0; }
[ "$agents_ok" = 1 ] && pass "agents: tools, omitClaudeMd and one review protocol"

# Skill sizes: compaction keeps about the first 5,000 tokens of each skill.
for f in skills/*/SKILL.md; do
	c=$(chars <"$f")
	[ "$c" -lt 19000 ] || fail "$f is $c characters, over 19,000"
done
c=$(body skills/track-intent/SKILL.md | chars)
if [ "$c" -lt 8500 ]; then pass "skill sizes (track-intent body $c characters)"; else fail "track-intent's body is $c characters, over 8,500"; fi

# The hook, under every shell at hand: silent, always exit 0, and its rules
# output under the 10,000-character cap even with long paths.
hook=hooks/track-intent.sh
command -v dash >/dev/null 2>&1 || fail "dash isn't installed, so the hook can't be tested under it"
shells=
for s in dash sh bash; do command -v "$s" >/dev/null 2>&1 && shells="$shells $s"; done
long=$tmp/a-folder-name-long-enough-to-stand-for-a-deep-home-directory-and-project-path-on-a-real-machine
mkdir -p "$long/project" "$long/state"
sid=00000000-0000-0000-0000-000000000000
run() { # <shell> <mode> <event> [state]
	printf '%s' "$3" | env -u KNACKPACK_INTENT CLAUDE_CODE_SESSION_ATTENDED=1 \
		XDG_STATE_HOME="${4:-$long/state}" CLAUDE_PROJECT_DIR="$long/project" \
		"$1" "$hook" "$2" >"$tmp/out" 2>"$tmp/err"
	code=$?
	if [ "$code" != 0 ] || [ -s "$tmp/err" ]; then
		fail "hook $2 under $1: exit $code, stderr: $(head -c 200 "$tmp/err")"
		return 1
	fi
}
event="{\"session_id\":\"$sid\",\"source\":\"startup\",\"prompt\":\"hi\",\"tool_input\":{\"file_path\":\"$long/project/a.md\"},\"last_assistant_message\":\"Noted: x\"}"
hook_ok=1
for s in $shells; do
	"$s" -n "$hook" 2>"$tmp/err" || { fail "hook syntax under $s: $(cat "$tmp/err")"; hook_ok=0; }
	rm -rf "$long/state/knackpack"
	for m in rules state prompt tool stop manual; do
		if [ "$m" = manual ]; then
			env XDG_STATE_HOME="$long/state" "$s" "$hook" manual "$sid" "$long/project" >"$tmp/out" 2>"$tmp/err" &&
				[ ! -s "$tmp/err" ] || { fail "hook manual under $s"; hook_ok=0; }
		else
			run "$s" "$m" "$event" || hook_ok=0
		fi
		if [ "$m" = rules ]; then
			size=$(wc -c <"$tmp/out" | tr -d ' ')
			if [ "$size" -gt 9900 ] || grep -q 'too long to print here' "$tmp/out"; then
				fail "hook rules output is $size bytes with long paths; keep it under 9,900"
				hook_ok=0
			fi
		fi
	done
	run "$s" prompt '' || hook_ok=0
	# Open proposals: a status follows "by <who>. ", and a reason may follow it.
	for d in "$long/state/knackpack/intent"/*/; do
		printf '%s\n' '# Intent record: test' '' '## Not agreed' \
			'- PROP-01: Reopen the rejected ticket, by Claude. open' \
			'- PROP-02: Wraps onto' '  a second line, by Claude. open (asked twice)' \
			'- PROP-03: Keep the open flag, by Claude. rejected' \
			'- PROP-04: Add a cache, by Claude. rejected for now: leaves it open' \
			'- PROP-05: Keep it, by Claude. open (raised again, by the developer)' \
			'- PROP-06: Add it, by Claude. rejected: too slow. Open questions moved.' >"$d$sid.md"
	done
	run "$s" prompt "$event" || hook_ok=0
	grep -q 'Open proposals: PROP-01, PROP-02, PROP-05\.$' "$tmp/out" || { fail "hook prompt under $s lists the wrong open proposals: $(grep -o 'Open proposals:.*' "$tmp/out")"; hook_ok=0; }
	rm -f "$long/state/knackpack/intent"/*/"$sid.md"
	# A full glossary and record still fit under the cap with long paths.
	for d in "$long/state/knackpack/intent"/*/; do
		awk 'BEGIN { for (i = 0; i < 200; i++) print "- term" i ": a meaning long enough to fill the glossary" }' >"${d}glossary.md"
		awk 'BEGIN { print "# Intent record: test"; for (i = 0; i < 200; i++) print "- REQ-" i ": a requirement long enough to fill the record" }' >"$d$sid.md"
	done
	run "$s" state "$event" || hook_ok=0
	state_size=$(wc -c <"$tmp/out" | tr -d ' ')
	[ "$state_size" -le 9900 ] || { fail "hook state output is $state_size bytes with long paths; keep it under 9,900"; hook_ok=0; }
	rm -f "$long/state/knackpack/intent"/*/glossary.md "$long/state/knackpack/intent"/*/"$sid.md"
	# A turn file that can't be written must not stop the hook.
	rm -rf "$long/state/knackpack/intent/.turns"
	: >"$long/state/knackpack/intent/.turns"
	for m in prompt tool stop; do run "$s" "$m" "$event" || hook_ok=0; done
	rm -f "$long/state/knackpack/intent/.turns"
	# The turn file is never written through a link, at the file or its folder.
	turns=$long/state/knackpack/intent/.turns
	printf 'KEEP\n' >"$tmp/sentinel"
	mkdir -p "$turns" "$tmp/elsewhere"
	ln -s "$tmp/sentinel" "$turns/$sid"
	for m in prompt tool; do run "$s" "$m" "$event" || hook_ok=0; done
	for m in prompt tool; do
		rm -f "$turns/$sid"
		ln "$tmp/sentinel" "$turns/$sid"
		run "$s" "$m" "$event" || hook_ok=0
	done
	rm -rf "$turns"
	ln -s "$tmp/elsewhere" "$turns"
	for m in prompt tool; do run "$s" "$m" "$event" || hook_ok=0; done
	rm -f "$turns"
	if [ "$(cat "$tmp/sentinel")" != KEEP ] || [ -n "$(ls -A "$tmp/elsewhere")" ]; then
		fail "hook under $s writes through a link"
		hook_ok=0
	fi
	rm -rf "$tmp/elsewhere"
	# A stopped session gets the short note instead of the rules.
	for d in "$long/state/knackpack/intent"/*/; do
		printf '# Intent record: test\n\n- Status: stopped · Updated: 2026-01-01\n' >"$d$sid.md"
	done
	run "$s" rules "$event" || hook_ok=0
	grep -q 'tracking is stopped for this session' "$tmp/out" || { fail "hook rules under $s ignores a stopped record"; hook_ok=0; }
done
[ "$hook_ok" = 1 ] && pass "hook under$shells (with long paths: rules $size bytes, state $state_size)"

# A changed plugin needs a new version, or installed copies never update.
cur=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' .claude-plugin/plugin.json)
pub=$(git show origin/main:.claude-plugin/plugin.json 2>/dev/null | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
if [ -z "$pub" ]; then
	fail "can't read the version on origin/main"
elif [ "$cur" = "$pub" ] && { ! git diff --quiet origin/main -- . || [ -n "$(git ls-files --others --exclude-standard)" ]; }; then
	fail "the plugin changed since origin/main but its version is still $cur"
else
	pass "version $cur (origin/main has $pub)"
fi

exit "$failed"
