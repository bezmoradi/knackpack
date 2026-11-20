#!/bin/sh
# Reports how consistent knackpack's output was across the repeated runs of
# an eval, and what changed between two versions:
#
#   sh evals/consistency.sh [--cases <folder>] <result> [<candidate result>]
#
# Each result is the folder `claude plugin eval` wrote under evals/results/,
# or its aggregate-result.json, or the file `--json` wrote; run it with
# `--runs 3` or more, since one run shows no consistency at all. With two
# results, the first is the base, such as origin/main's version, and the
# second the candidate.
#
# It's an analysis tool for eval results, not a pre-publish check, and it
# never runs a model. For each case it prints, for the run with the plugin
# (the `with` arm; a run without the plugin says nothing about knackpack's
# consistency):
#
#   - pass^N: whether every one of the N runs passed every grader, the
#     with-only ones included, and which graders failed in which runs. The
#     runner's own pass threshold isn't used, so a run that missed one grader
#     counts as failed here.
#   - for a reviewer's runs, the knackpack-verdict/1 word of each, and whether
#     it was the same in all of them;
#   - each finding the reviewer reported, keyed by its path:line and severity
#     from the reply's knackpack-finding/1 lines, split into those in every
#     run and those in only some. A reply with no finding lines, as one a
#     reviewer without a shell writes by hand may be, is read from its
#     findings table instead, and the report says so.
#
# Then, with two results, the cases that flipped between pass^N and not, or
# whose verdict word changed. Last come severe violations: every failed
# grader, or run that ended in an error, in a case whose prompt.md tags it
# `severe`, such as an edit by a report-only agent. They're listed one by one
# and left out of the summary counts, so a harm is never averaged away.
#
# The verdict and findings come from each run's trace, at the tracePath the
# result names, which the runner deletes unless it ran with --keep-temp. In a
# trace, a reviewer's own reply is the last text block of its Agent call's
# tool_use_result.content (the adjudicator's only when no other reviewer
# replied); a reviewer that ran in the background is read from its completion
# notice, and a run with neither from the session's final reply. The aggregate result doesn't hold a case's tags, so they're read from
# <folder>/<case>/prompt.md, by default the folder this script is in.
#
# It needs jq. It exits 0 after printing the report, 1 when a result can't be
# read, and 2 on a usage error.

export LC_ALL=C
unset CDPATH
me=consistency.sh
die() {
	printf '%s: %s\n' "$me" "$1" >&2
	exit "${2:-1}"
}
usage='usage: sh evals/consistency.sh [--cases <folder>] <result> [<candidate result>]'

cases_dir=$(dirname "$0")
while [ $# -gt 0 ]; do
	case $1 in
	--cases)
		[ $# -ge 2 ] || die "--cases needs a folder. $usage" 2
		cases_dir=$2
		shift 2
		;;
	-h | --help)
		printf '%s\n' "$usage"
		exit 0
		;;
	--) shift; break ;;
	-*) die "unknown option $1. $usage" 2 ;;
	*) break ;;
	esac
done
[ $# -ge 1 ] && [ $# -le 2 ] || die "$usage" 2
command -v jq >/dev/null 2>&1 || die "jq isn't installed, and it's needed to read the results' JSON: install it (brew install jq, apt-get install jq) and run this again"
[ -d "$cases_dir" ] || die "$cases_dir isn't a folder of eval cases"

tmp=$(mktemp -d "${TMPDIR:-/tmp}/knackpack-consistency.XXXXXX") || die "couldn't make a temporary folder"
trap 'rm -rf "$tmp"' EXIT
trap 'exit 1' HUP INT TERM

# The result file for a folder or a file argument.
result_file() { # <path>
	if [ -d "$1" ]; then
		[ -f "$1/aggregate-result.json" ] || die "$1 has no aggregate-result.json; give the folder claude plugin eval wrote under evals/results/, or that file"
		printf '%s\n' "$1/aggregate-result.json"
	elif [ -f "$1" ]; then
		printf '%s\n' "$1"
	else
		die "$1 doesn't exist"
	fi
}

# The reviewer's reply in one trace, as one line of JSON:
# {"read": true, "source": ..., "verdict": "pass"|"block"|null,
#  "findingsFrom": "lines"|"table"|null, "findings": [{"key", "severity"}]}.
# A finding's key is path:line, or the path, or for a finding with no path
# its title; the severity is matched separately.
# shellcheck disable=SC2016 # $-names here are jq's, not the shell's
reply_prog='
def agent_text($adjudicator):
	select(.type == "user") | .tool_use_result? | objects
	| select((.agentType? // "" | strings) as $a | ($a | startswith("knackpack:")) and (($a == "knackpack:adjudicator") == $adjudicator))
	| [.content[]? | objects | select(.type == "text") | .text | strings] | last // empty;
def location_key($loc):
	($loc | gsub("^\\s+|\\s+$"; "")) as $l
	| (if ($l | test("`")) then ($l | capture("`(?<p>[^`]*)`").p // "")
	   else ($l | capture("^(?<p>[^ \\t,;<]*)").p) end) as $p
	| ($p | sub("^\\./"; "")) as $p
	| if ($p | test("^[^/ ][^ ]*:[0-9]+((-|:)[0-9]+)?$")) then ($p | capture("^(?<f>.*):(?<n>[0-9]+)((-|:)[0-9]+)?$") | "\(.f):\(.n)")
	  elif $p == "" or ($p | test("^(n/?a|none|unknown|various|multiple)$"; "i")) then null
	  else $p end;
def table_findings($lines):
	($lines | to_entries | map(select(.value | test("^\\|\\s*ID\\s*\\|(.*\\|)?\\s*Severity\\s*\\|"; "i"))) | last) as $h
	| if $h == null then []
	  else ($h.value | gsub("\\\\\\|"; "\u0001") | split("|") | map(gsub("^\\s+|\\s+$"; "") | ascii_downcase)) as $cols
	  | ($cols | index("severity")) as $si | ($cols | index("location")) as $li | ($cols | index("finding")) as $fi
	  | if $si == null or $li == null then [] else
	    [$lines[($h.key + 1):][] | select(startswith("|"))] as $rows
	  | [ $rows[] | select(test("^\\|[\\s:|-]*$") | not)
	      | gsub("\\\\\\|"; "\u0001") | split("|")
	      | { severity: (.[$si] // "" | gsub("^\\s+|\\s+$"; "") | ascii_downcase),
	          key: (location_key(.[$li] // "") // ("(no location) " + ((if $fi == null then "" else .[$fi] end) // "" | gsub("^\\s+|\\s+$"; "") | gsub("\u0001"; "|")))) }
	      | select(.severity | test("^(critical|high|medium|low)$")) ]
	  end end;
def user_text:
	select(.type == "user" and .tool_use_result? == null) | .message.content?
	| if type == "string" then . else (arrays | .[] | objects | select(.type == "text") | .text | strings) end;
def has_verdict: test("knackpack-verdict/1: (pass|block)");
[inputs] as $all
| ([$all[] | agent_text(false)]) as $agent
| ([$all[] | agent_text(true) | select(has_verdict)] | last) as $jv
| ([$all[] | select(.type == "result") | .result? | strings]) as $final
| ([$agent[] | select(has_verdict)] | last) as $av
| ([$all[] | user_text | select(has_verdict)] | last) as $nv
| ([$final[] | select(has_verdict)] | last) as $fv
| if $av != null then {source: "reviewer reply", text: $av}
  elif $nv != null then {source: "background reviewer notification", text: $nv}
  elif $fv != null then {source: "final reply", text: $fv}
  elif $jv != null then {source: "adjudicator reply", text: $jv}
  elif ($agent | length) > 0 then {source: "reviewer reply", text: $agent[-1]}
  elif ($final | length) > 0 then {source: "final reply", text: $final[-1]}
  else {source: null, text: ""} end
| . as $r
| ($r.text | split("\n") | map(gsub("^\\s+|\\s+$"; ""))) as $lines
| ($lines | map(select(test("^knackpack-verdict/1: (pass|block)$"))) | last | if . == null then null else sub("^knackpack-verdict/1: "; "") end) as $verdict
| [$lines[] | select(startswith("knackpack-finding/1 ")) | .[20:] | fromjson? | objects] as $fl
| (if ($fl | length) > 0 then
	{from: "lines", list: [$fl[] | {severity: (.severity // "" | ascii_downcase),
		key: (if (.path | type) == "string" then .path + (if .line then ":\(.line)" else "" end) else "(no location) " + (.title // .id // "?" | tostring) end)}]}
   elif $verdict != null then
	(table_findings($lines)) as $t | if ($t | length) > 0 then {from: "table", list: $t} else {from: null, list: []} end
   else {from: null, list: []} end) as $f
| {read: true, source: $r.source, verdict: $verdict, findingsFrom: $f.from,
   findings: (if $r.source == "adjudicator reply" then null else $f.list end)}
'

# One result's cases, runs and replies, as one JSON document in $tmp/<label>.json.
analyze() { # <label> <path>
	label=$1
	file=$(result_file "$2") || exit 1
	jq -e 'type == "object" and (.cases | type) == "array"' "$file" >/dev/null 2>&1 ||
		die "$file isn't a claude plugin eval result: it isn't JSON with a cases array"
	schema=$(jq -r '.schemaVersion // "none"' "$file")
	[ "$schema" = 1 ] || die "$file has schemaVersion $schema, and this script reads only schemaVersion 1, the format it was written against; check what changed before extending it"
	jq -e '[.cases[] | .arms.with | type == "array"] | all' "$file" >/dev/null 2>&1 ||
		die "$file has a case with no runs with the plugin (arms.with), so there's nothing to compare"

	: >"$tmp/$label.replies"
	jq -r '.cases[] | .name as $c | .arms.with | to_entries[] | [$c, (.key + 1), (.value.tracePath // "")] | @tsv' "$file" >"$tmp/$label.runs" ||
		die "couldn't list the runs in $file"
	while IFS="$(printf '\t')" read -r name run trace; do
		if [ -n "$trace" ] && [ -f "$trace" ] && [ -r "$trace" ]; then
			jq -c -n "$reply_prog" <"$trace" 2>/dev/null >"$tmp/reply" && [ -s "$tmp/reply" ] ||
				printf '{"read":false,"why":"trace unreadable"}\n' >"$tmp/reply"
		else
			printf '{"read":false,"why":"no trace"}\n' >"$tmp/reply"
		fi
		jq -c --arg c "$name" --argjson r "$run" '{case: $c, run: $r} + .' "$tmp/reply" >>"$tmp/$label.replies"
	done <"$tmp/$label.runs"

	: >"$tmp/$label.tags"
	for name in $(jq -r '.cases[].name' "$file" | sort -u); do
		p="$cases_dir/$name/prompt.md"
		tags=
		# Only the frontmatter, the lines between the first two ---.
		[ -f "$p" ] && tags=$(sed -n '1{/^---$/!q;};2,/^---$/{s/^tags:[[:space:]]*\[\(.*\)\][[:space:]]*$/\1/p;}' "$p")
		jq -c -n --arg c "$name" --arg t "$tags" --argjson known "$([ -f "$p" ] && echo true || echo false)" \
			'{case: $c, known: $known, tags: ($t | split(",") | map(gsub("^\\s+|\\s+$"; "")) | map(select(. != "")))}' >>"$tmp/$label.tags"
	done

	jq -c --arg label "$label" --arg path "$2" \
		--slurpfile replies "$tmp/$label.replies" --slurpfile tags "$tmp/$label.tags" '
		{label: $label, path: $path, claude: .claudeVersion, model: (.suite.modelOverride // "default"),
		 judge: (.suite.judgeModel // "default"), ablation: .suite.ablation,
		 version: ([.suite.plugins[]? | select(.name == "knackpack") | .version] | first),
		 cases: [.cases[] | .name as $c
			| {name: $c,
			   tags: ([$tags[] | select(.case == $c) | .tags] | first // []),
			   tagsKnown: ([$tags[] | select(.case == $c) | .known] | first // false),
			   runs: [.arms.with | to_entries[] | (.key + 1) as $n | .value
				| {n: $n, error: .error,
				   failed: [.graders[]? | select(.passed != true) | .name],
				   reply: ([$replies[] | select(.case == $c and .run == $n)] | first)}
				| .ok = (.error == null and (.failed | length) == 0)]}]}' "$file" >"$tmp/$label.json" ||
		die "couldn't read the runs in $file"
}

analyze base "$1"
[ $# -eq 2 ] && analyze candidate "$2"

# shellcheck disable=SC2016 # $-names here are jq's, not the shell's
report_prog='
def count($xs; $v): [$xs[] | select(. == $v)] | length;
def runs($ns): if ($ns | length) == 1 then "run \($ns[0])" else "runs " + ($ns | map(tostring) | join(", ")) end;
def of_runs($n): "of \($n) run" + (if $n == 1 then "" else "s" end);
def summary(r):
	(r.runs | length) as $n
	| {n: $n, passed: ([r.runs[] | select(.ok)] | length),
	   all: ($n > 0 and ([r.runs[] | select(.ok | not)] | length) == 0),
	   verdicts: [r.runs[] | .reply.verdict? // null | select(. != null)],
	   severe: (r.tags | index("severe") != null)};
def case_report(c):
	summary(c) as $s
	| ([c.runs[] | .failed[]] | unique) as $gnames
	| ([c.runs[] | select(.reply.read == true)] | length) as $read
	| [c.runs[] | select(.reply.read == true and .reply.findings != null) | .reply.findings | map("\(.key) \(.severity)") | unique] as $fs
	| ($fs | add // [] | unique) as $keys
	| "\(c.name)" + (if (c.tags | length) > 0 then "  [\(c.tags | join(" "))]" elif c.tagsKnown then "" else "  [prompt.md not found, so no tags]" end),
	  "  pass^\($s.n): " + (if $s.all then "yes" else "no" end) + ", \($s.passed) \(of_runs($s.n)) passed every grader",
	  ($gnames[] as $g | "    failed: \($g) in " + runs([c.runs[] | select(.failed | index($g)) | .n])),
	  (c.runs[] | select(.error != null) | "    run \(.n) ended in an error: \(.error | tostring | .[0:160])"),
	  (if ($s.verdicts | length) > 0 then
		"  verdict: " + ($s.verdicts | unique | map("\(.) in \(count($s.verdicts; .))") | join(", "))
		+ " \(of_runs($s.n))" + (if ($s.verdicts | unique | length) == 1 and ($s.verdicts | length) == $s.n then ", the same in every run" elif ($s.verdicts | unique | length) > 1 then ", DIFFERENT between runs" else ", not read in every run" end)
	   else empty end),
	  (if ($s.verdicts | length) > 0 and ($fs | length) > 0 then
		([$keys[] as $k | {k: $k, in: count($fs | map(index($k) != null); true)}]) as $kc
		| (if ([c.runs[] | .reply.findingsFrom? // empty] | index("table")) then "  findings read from the findings table in " + runs([c.runs[] | select(.reply.findingsFrom? == "table") | .n]) + ", which had no knackpack-finding/1 lines" else empty end),
		  "  findings in every run (\($fs | length) " + (if ($fs | length) == 1 then "reply" else "replies" end) + " read): " + ([$kc[] | select(.in == ($fs | length)) | .k] | if length == 0 then "none" else join("; ") end),
		  ([$kc[] | select(.in < ($fs | length))] | if length == 0 then empty else "  findings in only some runs: " + (map("\(.k) (\(.in) of \($fs | length))") | join("; ")) end)
	   else empty end),
	  (if $read < $s.n and ([c.runs[] | select(.reply.read != true)] | length) > 0 then
		"  replies not read in \($s.n - $read) \(of_runs($s.n)) (" + ([c.runs[] | select(.reply.read != true) | .reply.why // "no trace"] | unique | join(", ")) + "); rerun with --keep-temp to keep the traces"
	   else empty end);
def result_report(r):
	"== \(r.label): \(r.path)",
	"   knackpack \(r.version // "?"), Claude Code \(r.claude // "?"), model \(r.model), judge \(r.judge), ablation \(r.ablation // "?")"
	+ (if r.ablation == "with-without" then "; only the run with the plugin is read" else "" end),
	"",
	(r.cases | sort_by(.name)[] | case_report(.), ""),
	(([r.cases[] | select(summary(.).severe | not)]) as $ns
	 | "   pass^N: \([$ns[] | select(summary(.).all)] | length) of \($ns | length) cases passed every grader in every run"
	   + (if ([r.cases[] | select(summary(.).severe)] | length) > 0 then " (severe cases left out; see below)" else "" end)),
	"";
def flips(b; c):
	[b.cases[] | .name] as $bn | [c.cases[] | .name] as $cn
	| "== changes from base to candidate",
	  ([b.cases[] | . as $x | (c.cases[] | select(.name == $x.name)) as $y
		| summary($x) as $p | summary($y) as $q
		| (if $p.all != $q.all then "  FLIP \($x.name): pass^N \(if $p.all then "yes" else "no" end) -> \(if $q.all then "yes" else "no" end) (\($p.passed) \(of_runs($p.n)) -> \($q.passed) \(of_runs($q.n)) passed)" else empty end),
		  (($p.verdicts | unique) as $pv | ($q.verdicts | unique) as $qv
		   | if ($pv | length) > 0 and ($qv | length) > 0 and $pv != $qv then "  VERDICT \($x.name): \($pv | join("/")) -> \($qv | join("/"))" else empty end)
	   ] | if length == 0 then "  no case flipped, and no verdict word changed" else .[] end),
	  ([$bn[] | select(. as $n | $cn | index($n) | not)] | if length > 0 then "  only in base: " + join(", ") else empty end),
	  ([$cn[] | select(. as $n | $bn | index($n) | not)] | if length > 0 then "  only in candidate: " + join(", ") else empty end),
	  "";
def severe(r):
	[r.cases[] | select(.tags | index("severe"))] as $sc
	| "== severe violations in \(r.label)",
	  (if ($sc | length) == 0 then "  no case in this result is tagged severe"
	   else ([$sc[] as $c | $c.runs[] | . as $run
		| (.failed[] | "  SEVERE \($c.name) run \($run.n): \(.) failed"),
		  (if .error != null then "  SEVERE \($c.name) run \($run.n): ended in an error, so its guards weren'\''t checked" else empty end)]
		| if length == 0 then "  none, in \([$sc[] | .runs | length] | add) run(s) of \($sc | length) severe case(s)" else .[] end)
	   end),
	  "";
($results | map({(.label): .}) | add) as $r
| result_report($r.base),
  (if $r.candidate then result_report($r.candidate), flips($r.base; $r.candidate) else empty end),
  severe($r.base),
  (if $r.candidate then severe($r.candidate) else empty end)
'

[ -f "$tmp/candidate.json" ] || : >"$tmp/candidate.json"
jq -r -n --slurpfile b "$tmp/base.json" --slurpfile c "$tmp/candidate.json" \
	'($b + $c) as $results | '"$report_prog" ||
	die "couldn't print the report"
