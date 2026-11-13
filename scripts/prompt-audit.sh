#!/bin/sh
# Audits knackpack's own instruction files with Claude Code's /doctor
# prompt-audit (2.1.283 or later) and fails while a high-confidence finding
# stands. It's for the maintainer's machine: each file it audits is a model run
# on your account, about $1 to $2, so CI and the plugin's hooks never run it.
#
#   sh scripts/prompt-audit.sh [<commit>]
#       audit the files <commit> (default HEAD) changes since origin/main
#   sh scripts/prompt-audit.sh --hook
#       the same for each commit git is about to push, reading git's pre-push
#       lines on standard input
#   sh scripts/prompt-audit.sh --install
#       install the pre-push hook that runs --hook in this clone
#   sh scripts/prompt-audit.sh --accept <path> [<commit>]
#       accept the findings reported for that version of the file, after
#       reading them, so they stop blocking
#
# It audits skills/*/SKILL.md, agents/*.md, .claude/CLAUDE.md and
# scripts/review-protocol.md. An agent whose only change is in its copy of the
# review protocol is skipped, since the protocol is audited as its own file.
# Each file is audited as committed, in a temporary worktree, so uncommitted
# work isn't what gets judged. Results are kept per file version in the
# repository's git folder, so pushing the same content again costs nothing and
# gives the same answer: a verdict varies from run to run, and rerolling until
# it passes would make the check meaningless.
#
# Exit status: 0 when nothing blocks, 1 when a high-confidence finding blocks,
# 2 when the audit couldn't run. git push --no-verify skips the hook.
#
# KNACKPACK_AUDIT_BUDGET caps each file's run in dollars (default 2); Claude
# Code checks it between turns, so a run can pass it by one turn's cost.
# KNACKPACK_AUDIT_MAX_FILES caps the number of files one run may audit
# (default 6).

set -u

fail() {
	printf 'prompt-audit: %s\n' "$1" >&2
	exit 2
}

top=$(git rev-parse --show-toplevel 2>/dev/null) || fail "not inside a git repository"
cd "$top" || fail "can't enter $top"
grep -q '"name": *"knackpack"' .claude-plugin/plugin.json 2>/dev/null || fail "this isn't a knackpack checkout"
store=$(cd "$(git rev-parse --git-common-dir)" && pwd)/knackpack-prompt-audit || fail "can't find the git folder"
base=origin/main
budget=${KNACKPACK_AUDIT_BUDGET:-2}
max_files=${KNACKPACK_AUDIT_MAX_FILES:-6}
case $max_files in '' | *[!0-9]*) fail "KNACKPACK_AUDIT_MAX_FILES must be a whole number" ;; esac

# The reply the audit must give: its report, whether it ran, and each finding
# with the confidence the audit gives it, so blocking doesn't rest on parsing
# prose.
schema='{"type":"object","additionalProperties":false,"required":["audit_ran","report","findings"],"properties":{"audit_ran":{"type":"boolean","description":"false if the prompt audit could not run or could not read the file"},"report":{"type":"string","description":"the full audit report in Markdown"},"findings":{"type":"array","items":{"type":"object","additionalProperties":false,"required":["location","confidence","action","summary"],"properties":{"location":{"type":"string"},"confidence":{"enum":["high","medium","low"]},"action":{"type":"string"},"summary":{"type":"string"}}}}}}'

key() { # <path> <blob>: the name a file version's results are kept under
	printf '%s-%s' "$2" "$(printf '%s' "$1" | tr '/' '_')"
}

before_protocol() { # <commit> <path>: the file up to its review protocol
	git show "$1:$2" 2>/dev/null | sed '/^## Review protocol$/,$d'
}

wt=
tmp=
cleanup() {
	[ -z "$wt" ] || git worktree remove --force "$wt" >/dev/null 2>&1
	[ -z "$tmp" ] || rm -rf "$tmp"
}
trap cleanup EXIT
trap 'exit 2' INT TERM HUP

audit_one() { # <path> <key>: one headless audit run in the worktree
	(cd "$wt" && KNACKPACK_INTENT=off KNACKPACK_CHALLENGE=off KNACKPACK_CONTEXT=off KNACKPACK_COMPACT=off \
		claude -p "/doctor prompt-audit $1" --output-format json --json-schema "$schema" \
		--max-budget-usd "$budget" --no-session-persistence </dev/null) >"$tmp/$2.json" 2>"$tmp/$2.err"
	jq -r '.total_cost_usd // 0' "$tmp/$2.json" >"$tmp/$2.cost" 2>/dev/null
	if jq -e '.structured_output.audit_ran == true and (.structured_output.findings | type) == "array"' \
		"$tmp/$2.json" >/dev/null 2>&1; then
		jq -r '.structured_output.report' "$tmp/$2.json" >"$store/$2.md" &&
			mv "$tmp/$2.json" "$store/$2.json"
	fi
}

audit() { # <commit>: audit what it changes since the base; prints and returns the status
	cleanup # what an earlier commit of the same push left
	wt="" tmp=""
	commit=$(git rev-parse --verify --quiet "$1^{commit}") || fail "no commit $1"
	git rev-parse --verify --quiet "$base^{commit}" >/dev/null || fail "no $base; run git fetch"
	mb=$(git merge-base "$base" "$commit") || fail "$commit shares no history with $base"
	tmp=$(mktemp -d "${TMPDIR:-/tmp}/kp-prompt-audit.XXXXXX") || fail "can't make a temporary folder"
	mkdir -p "$store" || fail "can't create $store"
	git diff --name-only --diff-filter=d "$mb" "$commit" -- 'skills/*/SKILL.md' 'agents/*.md' \
		.claude/CLAUDE.md scripts/review-protocol.md >"$tmp/changed" || fail "can't list the changed files"
	: >"$tmp/list"
	while IFS= read -r f; do
		case $f in agents/*)
			if git cat-file -e "$mb:$f" 2>/dev/null &&
				[ "$(before_protocol "$mb" "$f" | git hash-object --stdin)" = "$(before_protocol "$commit" "$f" | git hash-object --stdin)" ]; then
				continue
			fi ;;
		esac
		blob=$(git rev-parse "$commit:$f") || fail "can't read $f at $commit"
		printf '%s %s\n' "$f" "$(key "$f" "$blob")" >>"$tmp/list"
	done <"$tmp/changed"
	if [ ! -s "$tmp/list" ]; then
		printf 'prompt-audit: %s changes no instruction file since %s\n' "$(git rev-parse --short "$commit")" "$base"
		return 0
	fi
	todo=0
	while read -r f k; do [ -f "$store/$k.json" ] || todo=$((todo + 1)); done <"$tmp/list"
	if [ "$todo" -gt "$max_files" ]; then
		fail "$todo files need auditing, more than KNACKPACK_AUDIT_MAX_FILES=$max_files; at up to \$$budget each, set it higher to run them, or push with --no-verify"
	fi
	if [ "$todo" -gt 0 ]; then
		command -v claude >/dev/null 2>&1 || fail "claude isn't on PATH"
		command -v jq >/dev/null 2>&1 || fail "jq isn't on PATH"
		wt=$tmp/tree
		git worktree add --detach --quiet "$wt" "$commit" 2>/dev/null || fail "can't check out $commit in a worktree"
		printf 'prompt-audit: auditing %d file(s) at %s, about a minute or two each, up to $%s each\n' \
			"$todo" "$(git rev-parse --short "$commit")" "$budget"
		n=0
		while read -r f k; do
			[ ! -f "$store/$k.json" ] || continue
			audit_one "$f" "$k" &
			n=$((n + 1))
			[ "$n" -lt 4 ] || { wait; n=0; }
		done <"$tmp/list"
		wait
		printf 'prompt-audit: spent $%s\n' "$(cat "$tmp"/*.cost 2>/dev/null | awk '{ s += $1 } END { printf "%.2f", s }')"
	fi
	status=0
	while read -r f k; do
		if [ ! -f "$store/$k.json" ]; then
			why=$(jq -r 'if .structured_output.audit_ran == false then "the audit says it could not run: " + (.structured_output.report | .[0:300]) else (.subtype // "no reply") + " " + (.result // "" | .[0:300]) end' "$tmp/$k.json" 2>/dev/null)
			printf '  ERROR    %s: %s\n' "$f" "${why:-$(head -c 300 "$tmp/$k.err" 2>/dev/null)}"
			[ -f "$tmp/$k.json" ] && cp "$tmp/$k.json" "$store/$k.failed.json" 2>/dev/null &&
				printf '           raw reply: %s\n' "$store/$k.failed.json"
			status=2
			continue
		fi
		high=$(jq '[.structured_output.findings[] | select(.confidence == "high")] | length' "$store/$k.json")
		others=$(jq '[.structured_output.findings[] | select(.confidence != "high")] | length' "$store/$k.json")
		if [ "$high" -eq 0 ]; then
			printf '  pass     %s (%s lower-confidence finding(s)); report: %s\n' "$f" "$others" "$store/$k.md"
		elif [ -f "$store/$k.accepted" ]; then
			printf '  accepted %s (%s high-confidence finding(s) accepted); report: %s\n' "$f" "$high" "$store/$k.md"
		else
			printf '  BLOCKED  %s: %s high-confidence finding(s); report: %s\n' "$f" "$high" "$store/$k.md"
			jq -r '.structured_output.findings[] | select(.confidence == "high") | "           - " + .location + " (" + .action + "): " + .summary' "$store/$k.json"
			[ "$status" -eq 2 ] || status=1
		fi
	done <"$tmp/list"
	if [ "$status" -eq 1 ]; then
		printf 'prompt-audit: fix the findings and commit, or, once you have read them and they are wrong or intended, run\n  sh scripts/prompt-audit.sh --accept <path> %s\n' "$(git rev-parse --short "$commit")"
	fi
	return "$status"
}

case ${1:-} in
--install)
	hook=$(git rev-parse --git-path hooks/pre-push) || fail "can't find the hooks folder"
	if [ -e "$hook" ] && ! grep -q 'knackpack prompt-audit hook' "$hook"; then
		fail "$hook already exists and isn't this script's; add a line running sh scripts/prompt-audit.sh --hook to it yourself"
	fi
	mkdir -p "$(dirname "$hook")" || fail "can't create the hooks folder"
	cat >"$hook" <<'EOF'
#!/bin/sh
# knackpack prompt-audit hook, installed by sh scripts/prompt-audit.sh --install
s=$(git rev-parse --show-toplevel)/scripts/prompt-audit.sh
[ -f "$s" ] || exit 0 # a branch from before the script existed
exec sh "$s" --hook
EOF
	chmod +x "$hook" || fail "can't make $hook executable"
	printf 'prompt-audit: installed %s\n' "$hook"
	;;
--accept)
	[ -n "${2:-}" ] || fail "usage: sh scripts/prompt-audit.sh --accept <path> [<commit>]"
	blob=$(git rev-parse --verify --quiet "${3:-HEAD}:$2") || fail "no $2 at ${3:-HEAD}"
	k=$(key "$2" "$blob")
	[ -f "$store/$k.json" ] || fail "no audit result for that version of $2; run the audit first"
	: >"$store/$k.accepted" || fail "can't write to $store"
	printf 'prompt-audit: accepted the findings for this version of %s; a change to the file is audited again\n' "$2"
	;;
--hook)
	worst=0
	while read -r _ lsha _ _; do
		case $lsha in *[!0]*) ;; *) continue ;; esac # all zeros: a branch being deleted
		audit "$lsha"
		s=$?
		[ "$s" -le "$worst" ] || worst=$s
	done
	[ "$worst" -eq 0 ] || printf 'prompt-audit: push stopped; git push --no-verify skips this check\n' >&2
	exit "$worst"
	;;
-*)
	fail "unknown option $1"
	;;
*)
	audit "${1:-HEAD}"
	exit $?
	;;
esac
