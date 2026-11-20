#!/bin/sh
# Checks, before a push, that a changed skill or agent description still
# starts it when it should and doesn't when it shouldn't. Claude chooses a
# skill or agent from its description alone, so a reworded description can
# stop it starting, or start it where it mustn't, with every file still
# reading well. It's for the maintainer's machine: it runs eval cases with
# claude plugin eval on your account, so CI and the plugin's hooks never run
# it.
#
#   sh scripts/trigger-gate.sh [<commit>]
#       gate the descriptions <commit> (default HEAD) changes since origin/main
#   sh scripts/trigger-gate.sh --hook
#       the same for each commit git is about to push, reading git's pre-push
#       lines on standard input
#   sh scripts/trigger-gate.sh --install
#       install the pre-push hook, the one sh scripts/prompt-audit.sh
#       --install writes, whose --hook runs the prompt audit and then this gate
#   sh scripts/trigger-gate.sh --accept <component> [<commit>]
#       accept the gate's verdict on that component's description change,
#       after reading it, so it stops blocking; <component> is its name as
#       knackpack ships it, such as knackpack:research
#
# A description is the description: line in the frontmatter of
# skills/*/SKILL.md or agents/*.md. A skill with disable-model-invocation:
# true is skipped, since its description doesn't decide when it starts, and so
# is a new one, which has no earlier description to compare with.
#
# For each changed component it takes the eval cases tagged trigger and
# "starts:<component>" or "quiet:<component>" as they are on origin/main, so a
# change can't write or tune its own test, and runs each once on the merge
# base with origin/main and once on <commit>, both as committed, in temporary
# worktrees whose evals/ folder is replaced by origin/main's. It runs them as
# CLAUDE.md's eval table says for trigger cases: --scaffold, --ablation none
# and --allow-tools Edit, with --trust-plugin, since the worktrees hold this
# repository's own commits and a run under --json can't ask. Cases tagged for
# a component but not trigger count for scripts/check.sh's coverage check, but
# need other grants and cost a whole review each, so they aren't run here.
#
# A case's outcome is its grader that checks the component: a tool_used or
# tool_order grader on the Skill or Agent tool naming it, with max: 0 for a
# quiet case. The gate blocks when the share of runs in which the component
# started where it should is lower on <commit> than on the base, or the share
# in which it stayed quiet where it should is, and when no case could measure
# a changed component at all. Each case's result is kept in the repository's
# git folder per component, description, case version, run count and Claude
# Code version, so pushing the same description again costs nothing and gives
# the same answer: a run's outcome varies, and rerolling until it passes
# would make the check meaningless. A run that ended in an error isn't kept.
#
# Exit status: 0 when nothing blocks, 1 when a component regressed or wasn't
# measured, 2 when the gate couldn't run. git push --no-verify skips the hook.
#
# KNACKPACK_TRIGGER_BUDGET caps the spend on each commit gated, in dollars,
# across every case and both versions (default 5); claude plugin eval checks
# it before each run starts, so a run can pass it by one run's cost, and a
# case the budget leaves unrun is an error. KNACKPACK_TRIGGER_RUNS sets each
# case's runs (default: the case's own runs, mostly 1); a different count
# measures afresh, and more runs give a rate one run's luck can't tip.

set -u

fail() {
	printf 'trigger-gate: %s\n' "$1" >&2
	exit 2
}

top=$(git rev-parse --show-toplevel 2>/dev/null) || fail "not inside a git repository"
cd "$top" || fail "can't enter $top"
grep -q '"name": *"knackpack"' .claude-plugin/plugin.json 2>/dev/null || fail "this isn't a knackpack checkout"
store=$(cd "$(git rev-parse --git-common-dir)" && pwd)/knackpack-trigger-gate || fail "can't find the git folder"
base=origin/main
budget=${KNACKPACK_TRIGGER_BUDGET:-5}
case $budget in '' | . | *[!0-9.]* | *.*.*) fail "KNACKPACK_TRIGGER_BUDGET must be a number of dollars" ;; esac
runs=${KNACKPACK_TRIGGER_RUNS:-}
case $runs in '') ;; *[!0-9]* | 0*) fail "KNACKPACK_TRIGGER_RUNS must be a whole number from 1" ;; esac

desc() { # <commit> <path>: the description line of the file's frontmatter
	git show "$1:$2" 2>/dev/null | awk 'NR == 1 && !/^---[[:space:]]*$/ { exit } /^---[[:space:]]*$/ { if (++n == 2) exit; next } /^description:/ { print; exit }'
}

model_off() { # <commit> <path>: true for a skill that sets disable-model-invocation: true
	git show "$1:$2" 2>/dev/null | awk '/^---[[:space:]]*$/ { if (++n == 2) exit; next } n == 1 && /^disable-model-invocation:[[:space:]]*true[[:space:]]*$/ { f = 1 } END { exit !f }'
}

hash() { git hash-object --stdin; } # the text on stdin's git hash, as a short, safe file name

wt_base=
wt_cand=
tmp=
in_hook=
cleanup() {
	[ -z "$wt_base" ] || git worktree remove --force "$wt_base" >/dev/null 2>&1
	[ -z "$wt_cand" ] || git worktree remove --force "$wt_cand" >/dev/null 2>&1
	[ -z "$tmp" ] || rm -rf "$tmp"
}
trap cleanup EXIT
trap 'exit 2' INT TERM HUP

# Reads one case's outcome for one component from claude plugin eval's
# result: {"runs": [true, false, ...]}, true where the component started
# (starts) or stayed quiet (quiet) as the case wants, or {"error": "..."}.
# shellcheck disable=SC2016 # $-names here are jq's, not the shell's
outcome_prog='
def names_it($im): ($im // "") | test("(^|[^a-z0-9-])" + $n + "([^a-z0-9-]|$)");
def any_agent($im): $tool == "Agent" and (($im // "") == "" or $im == "knackpack:");
([.cases[]? | select(.name == $case)] | first) as $c
| if $c == null then {error: (if .partial == true then "the run stopped before this case: " + (.partialReason // "partial result" | tostring) else "the result has no case of that name" end)}
  else
  [$c.graders[]? | select(
	if $kind == "starts" then
		(.type == "tool_used" and .config.tool == $tool and names_it(.config.input_match) and .config.max != 0 and (.config.min // 1) != 0)
		or (.type == "tool_order" and (.config.before | type) == "object" and .config.before.tool == $tool and names_it(.config.before.input_match))
	else .type == "tool_used" and .config.tool == $tool and .config.max == 0 and (names_it(.config.input_match) or any_agent(.config.input_match)) end)
   | .name] as $g
  | if ($g | length) == 0 then {error: "no grader in the case checks that knackpack:\($n) \(if $kind == "starts" then "starts" else "stays quiet" end)"}
    else [$c.arms.with[]?
	| if .error != null then {error: ("a run ended in an error: " + (.error | tostring | .[0:300]))}
	  else [.graders[]? | select(.name | IN($g[]))] as $r
	  | if ($r | length) != ($g | length) or ($r | any(.passed | type != "boolean")) then {error: "a run has no result for the grader that checks the component"}
	    else {ok: ($r | all(.passed))} end end] as $rs
    | if ($rs | length) == 0 then {error: "the case has no runs with the plugin"}
      elif ($rs | any(has("error"))) then ([$rs[] | select(has("error"))] | first)
      else {runs: [$rs[].ok]} end end end'

spent() { # the dollars this gate run has spent so far
	cat "$tmp"/*.cost 2>/dev/null | awk '{ s += $1 } END { printf "%.2f", s }'
}

measure() { # <tree> <case> <kind> <tool> <name> <key>: run one case, keeping its outcome when it ran
	dir=$1 c=$2 kind=$3 tool=$4 n=$5 k=$6
	left=$(spent | awk -v b="$budget" '{ l = b - $1; if (l < 0.005) print 0; else printf "%.2f", l }')
	if [ "$left" = 0 ]; then
		printf '{"error":"the budget of $%s was spent before this case could run; set KNACKPACK_TRIGGER_BUDGET higher"}\n' "$budget" >"$tmp/$k.outcome"
		return
	fi
	set -- claude plugin eval "$dir" --case "$c" --scaffold --ablation none --trust-plugin --max-cost-usd "$left"
	[ -z "$runs" ] || set -- "$@" --runs "$runs"
	"$@" --allow-tools Edit --json "$tmp/$k.result.json" </dev/null >"$tmp/$k.out" 2>"$tmp/$k.err"
	jq -r '(.costUsd // 0) + ([.cases[]?.arms[]?[]?.judgeCostUsd // 0] | add // 0)' "$tmp/$k.result.json" >"$tmp/$k.cost" 2>/dev/null ||
		rm -f "$tmp/$k.cost"
	if ! jq -c --arg case "$c" --arg kind "$kind" --arg tool "$tool" --arg n "$n" "$outcome_prog" \
		"$tmp/$k.result.json" >"$tmp/$k.outcome" 2>/dev/null; then
		why=$(head -c 300 "$tmp/$k.err" 2>/dev/null | tr '\n' ' ' | sed 's/[[:space:]]*$//')
		jq -cn --arg w "claude plugin eval gave no result it could read${why:+: $why}" '{error: $w}' >"$tmp/$k.outcome"
	fi
	if jq -e 'has("runs")' "$tmp/$k.outcome" >/dev/null 2>&1; then
		cp "$tmp/$k.result.json" "$store/$k.result.json" && mv "$tmp/$k.outcome" "$store/$k.json"
	fi
}

gate() { # <commit>: gate the descriptions it changes since the base; prints and returns the status
	cleanup # what an earlier commit of the same push left
	wt_base="" wt_cand="" tmp=""
	commit=$(git rev-parse --verify --quiet "$1^{commit}") || fail "no commit $1"
	git rev-parse --verify --quiet "$base^{commit}" >/dev/null || fail "no $base; run git fetch"
	mb=$(git merge-base "$base" "$commit") || fail "$commit shares no history with $base"
	short=$(git rev-parse --short "$commit") mbshort=$(git rev-parse --short "$mb")
	tmp=$(mktemp -d "${TMPDIR:-/tmp}/kp-trigger-gate.XXXXXX") || fail "can't make a temporary folder"
	mkdir -p "$store" || fail "can't create $store"
	git diff --name-only --diff-filter=d "$mb" "$commit" -- 'skills/*/SKILL.md' 'agents/*.md' >"$tmp/changed" ||
		fail "can't list the changed files"
	: >"$tmp/list"
	: >"$tmp/notes"
	while IFS= read -r f; do
		case $f in
		skills/*/SKILL.md) tool=Skill n=${f#skills/} && n=${n%/SKILL.md} ;;
		agents/*/*) continue ;;
		agents/*.md) tool=Agent n=${f#agents/} && n=${n%.md} ;;
		*) continue ;;
		esac
		new=$(desc "$commit" "$f") old=$(desc "$mb" "$f")
		[ "$new" != "$old" ] || continue
		if ! git cat-file -e "$mb:$f" 2>/dev/null; then
			printf '  new      knackpack:%s: no description on %s to compare with; its cases join this gate once they are on %s\n' "$n" "$mbshort" "$base" >>"$tmp/notes"
		elif [ "$tool" = Skill ] && model_off "$commit" "$f"; then
			printf '  skipped  knackpack:%s: disable-model-invocation: true, so its description does not decide when it starts\n' "$n" >>"$tmp/notes"
		else
			printf '%s %s %s\n' "$tool" "$n" "$f" >>"$tmp/list"
		fi
	done <"$tmp/changed"
	if [ ! -s "$tmp/list" ]; then
		if [ -s "$tmp/notes" ]; then
			printf 'trigger-gate: %s changes no description this gate measures since %s\n' "$short" "$base"
			cat "$tmp/notes"
		else
			printf 'trigger-gate: %s changes no skill or agent description since %s\n' "$short" "$base"
		fi
		return 0
	fi
	command -v jq >/dev/null 2>&1 || fail "jq isn't on PATH"
	command -v claude >/dev/null 2>&1 || fail "claude isn't on PATH"
	version=$(claude --version </dev/null 2>/dev/null | head -n 1)
	[ -n "$version" ] || fail "claude --version printed nothing"

	# The cases as they are on origin/main: <case> <kind> <component> for each
	# case tagged trigger, and the count of the others.
	mkdir "$tmp/main" && git archive "$base" evals | tar -xf - -C "$tmp/main" || fail "can't read the eval cases on $base"
	: >"$tmp/tags"
	if [ -n "$(ls "$tmp/main/evals"/*/prompt.md 2>/dev/null)" ]; then
		(cd "$tmp/main/evals" && awk '
			FNR == 1 { n = 0; c = FILENAME; sub(/\/prompt\.md$/, "", c); sub(/.*\//, "", c) }
			/^---[[:space:]]*$/ { n++; next }
			n == 1 && /^tags:[[:space:]]*\[.*\][[:space:]]*$/ {
				v = $0; sub(/^tags:[[:space:]]*\[/, "", v); sub(/\][[:space:]]*$/, "", v); gsub(/[[:space:]"\047]/, "", v)
				m = split(v, a, ","); t = 0
				for (i = 1; i <= m; i++) if (a[i] == "trigger") t = 1
				for (i = 1; i <= m; i++) if (a[i] ~ /^(starts|quiet):/) { k = a[i]; sub(/:.*/, "", k); x = a[i]; sub(/^[a-z]*:/, "", x); print c, k, x, t }
			}' ./*/prompt.md) | sort -u >"$tmp/tags" || fail "can't read the tags of the eval cases on $base"
	fi

	# What to run: <side> <case> <kind> <tool> <name> <key>, for each component's
	# cases on each side, unless a result is kept.
	: >"$tmp/plan"
	while read -r tool n f; do
		awk -v c="knackpack:$n" '$3 == c && $4 == 1 { print $1, $2 }' "$tmp/tags" >"$tmp/cases-$n"
		[ -s "$tmp/cases-$n" ] || continue
		for side in base cand; do
			if [ "$side" = base ]; then d=$(desc "$mb" "$f"); else d=$(desc "$commit" "$f"); fi
			while read -r c kind; do
				tree=$(git rev-parse "$base:evals/$c") || fail "can't read evals/$c on $base"
				key=$n-$(printf 'trigger-gate/1\n%s\n%s\n%s\n%s\n%s\n%s\n' "$n" "$kind" "$d" "$tree" "${runs:-case}" "$version" | hash)
				printf '%s %s %s %s %s %s\n' "$side" "$c" "$kind" "$tool" "$n" "$key" >>"$tmp/plan"
			done <"$tmp/cases-$n"
		done
	done <"$tmp/list"
	todo=0
	while read -r _ _ _ _ _ k; do [ -f "$store/$k.json" ] || todo=$((todo + 1)); done <"$tmp/plan"
	if [ "$todo" -gt 0 ]; then
		for side in base cand; do
			if [ "$side" = base ]; then rev=$mb wt_base=$tmp/base wt=$tmp/base; else rev=$commit wt_cand=$tmp/cand wt=$tmp/cand; fi
			git worktree add --detach --quiet "$wt" "$rev" 2>/dev/null || fail "can't check out $rev in a worktree"
			rm -rf "$wt/evals" && cp -R "$tmp/main/evals" "$wt/evals" || fail "can't put $base's eval cases into the worktree of $rev"
		done
		printf 'trigger-gate: running %d eval case run(s) for the descriptions %s changes, on %s and on %s, minutes each, up to $%s in all\n' \
			"$todo" "$short" "$mbshort" "$short" "$budget"
		while read -r side c kind tool n k; do
			[ ! -f "$store/$k.json" ] || continue
			if [ "$side" = base ]; then wt=$wt_base; else wt=$wt_cand; fi
			measure "$wt" "$c" "$kind" "$tool" "$n" "$k"
		done <"$tmp/plan"
		printf 'trigger-gate: spent $%s\n' "$(spent)"
		[ -z "$in_hook" ] || printf 'trigger-gate: if the push now fails with a closed connection, the runs outlasted it; push again, which reuses these results\n'
	fi

	status=0
	printf 'trigger-gate: descriptions %s changes, base %s -> %s\n' "$short" "$mbshort" "$short"
	cat "$tmp/notes"
	while read -r tool n f; do
		pair=$n-$(printf '%s\n%s\n%s\n%s\n' "$tool" "$n" "$(desc "$mb" "$f")" "$(desc "$commit" "$f")" | hash)
		if [ ! -s "$tmp/cases-$n" ]; then
			others=$(awk -v c="knackpack:$n" '$3 == c && $4 == 0' "$tmp/tags" | wc -l | tr -d ' ')
			line="no case on $base is tagged trigger and \"starts:knackpack:$n\" or \"quiet:knackpack:$n\""
			[ "$others" = 0 ] || line="$line; $others other tagged case(s) need other grants and aren't run here"
			if [ -f "$store/$pair.accepted" ]; then
				printf '  accepted knackpack:%s, not measured: %s\n' "$n" "$line"
			else
				printf '  NOT MEASURED knackpack:%s: %s\n' "$n" "$line"
				printf 'not measured\n' >"$store/$pair.verdict"
				[ "$status" -eq 2 ] || status=1
			fi
			continue
		fi
		# <case> <kind> <base passes> <base runs> <candidate passes> <candidate runs> <candidate key>
		: >"$tmp/rows"
		err=
		while read -r c kind; do
			row="$c $kind"
			for side in base cand; do
				k=$(awk -v s="$side" -v c="$c" -v n="$n" '$1 == s && $2 == c && $5 == n { print $6; exit }' "$tmp/plan")
				if [ -f "$store/$k.json" ]; then
					row="$row $(jq -r '"\([.runs[] | select(.)] | length) \(.runs | length)"' "$store/$k.json")"
				else
					why=$(jq -r '.error // empty' "$tmp/$k.outcome" 2>/dev/null)
					if [ "$side" = base ]; then at="$mbshort (base)"; else at=$short; fi
					err="$err$(printf '\n           - %s (%s) on %s: %s' "$c" "$kind" "$at" "${why:-not run}")"
					row="$row ? ?"
				fi
			done
			printf '%s %s\n' "$row" "$k" >>"$tmp/rows"
		done <"$tmp/cases-$n"
		if [ -n "$err" ]; then
			printf '  ERROR    knackpack:%s: a case could not be measured, so nothing was compared:%s\n' "$n" "$err"
			status=2
			continue
		fi
		summary=$(awk '
			{ bp[$2] += $3; bn[$2] += $4; cp[$2] += $5; cn[$2] += $6; seen[$2] = 1 }
			END {
				for (i = 1; i <= 2; i++) {
					k = i == 1 ? "starts" : "quiet"
					if (!seen[k]) { s = s sep k " not measured (no case)"; sep = ", "; continue }
					w = k == "starts" ? "started" : "stayed quiet"
					s = s sep w " " bp[k] "/" bn[k] " -> " cp[k] "/" cn[k]; sep = ", "
					if (cp[k] * bn[k] < bp[k] * cn[k]) drop = 1
				}
				print (drop ? "drop " : "same ") s
			}' "$tmp/rows")
		if [ "${summary%% *}" = same ]; then
			printf '  pass     knackpack:%s: %s\n' "$n" "${summary#* }"
		elif [ -f "$store/$pair.accepted" ]; then
			printf '  accepted knackpack:%s: %s\n' "$n" "${summary#* }"
		else
			printf '  BLOCKED  knackpack:%s: %s\n' "$n" "${summary#* }"
			awk -v d="$store" '{ printf "           - %s (%s): %s/%s -> %s/%s; result: %s/%s.result.json\n", $1, $2, $3, $4, $5, $6, d, $7 }' "$tmp/rows"
			printf 'blocked: %s\n' "${summary#* }" >"$store/$pair.verdict"
			[ "$status" -eq 2 ] || status=1
		fi
	done <"$tmp/list"
	if [ "$status" -eq 1 ]; then
		printf 'trigger-gate: fix the description and commit; a component no case measures needs its cases on %s first. Once you have read the results and the change is intended, or a case is wrong, run\n  sh scripts/trigger-gate.sh --accept <component> %s\n' "$base" "$short"
	fi
	return "$status"
}

case ${1:-} in
--install)
	[ -f "$top/scripts/prompt-audit.sh" ] || fail "scripts/prompt-audit.sh, which installs the hook, is missing"
	exec sh "$top/scripts/prompt-audit.sh" --install
	;;
--accept)
	[ -n "${2:-}" ] || fail "usage: sh scripts/trigger-gate.sh --accept <component> [<commit>]"
	n=${2#knackpack:}
	if git cat-file -e "${3:-HEAD}:agents/$n.md" 2>/dev/null; then tool=Agent f=agents/$n.md
	elif git cat-file -e "${3:-HEAD}:skills/$n/SKILL.md" 2>/dev/null; then tool=Skill f=skills/$n/SKILL.md
	else fail "no skill or agent $2 at ${3:-HEAD}"; fi
	commit=$(git rev-parse --verify --quiet "${3:-HEAD}^{commit}") || fail "no commit ${3:-HEAD}"
	mb=$(git merge-base "$base" "$commit") || fail "$commit shares no history with $base"
	pair=$n-$(printf '%s\n%s\n%s\n%s\n' "$tool" "$n" "$(desc "$mb" "$f")" "$(desc "$commit" "$f")" | hash)
	[ -f "$store/$pair.verdict" ] || fail "the gate has blocked nothing for that description of knackpack:$n; run it first"
	: >"$store/$pair.accepted" || fail "can't write to $store"
	printf 'trigger-gate: accepted the verdict on this description of knackpack:%s; a change to it is gated again\n' "$n"
	;;
--hook)
	in_hook=1
	worst=0
	while read -r _ lsha _ _; do
		case $lsha in *[!0]*) ;; *) continue ;; esac # all zeros: a branch being deleted
		gate "$lsha"
		s=$?
		[ "$s" -le "$worst" ] || worst=$s
	done
	[ "$worst" -eq 0 ] || printf 'trigger-gate: push stopped; git push --no-verify skips this check\n' >&2
	exit "$worst"
	;;
-*)
	fail "unknown option $1"
	;;
*)
	gate "${1:-HEAD}"
	exit $?
	;;
esac
