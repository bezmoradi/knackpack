#!/bin/sh
# Runs knackpack's pre-publish checks: the rules in .claude/CLAUDE.md that a
# script can check. Prints one line per check and exits 1 if any fails.
# Needs git, dash, jq and the claude CLI; bash is used too when installed, and
# so are the linters pinned in .github/linters.
#
#   sh scripts/check.sh

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

# The agents: report-only, no CLAUDE.md, each naming the file it saves its
# report to (a subagent doesn't see its own name, and the protocol asks for the
# name its instructions give), and each with an exact copy of the review
# protocol's one source.
# Claude Code splits tools on commas and on spaces outside parentheses. What's
# in parentheses doesn't narrow Agent in a subagent, so it's dropped, and Task
# is the Agent tool's old name.
tool_is() { printf '%s\n' "$tools" | sed 's/([^)]*)//g' | tr ', \t' '\n\n\n' | grep -Ex "$1" >/dev/null; }
agents_ok=1
brief_ok=1
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
		case $name in adversarial-reviewer | security-reviewer | architecture-reviewer) ;; *) fail "$name has the Agent tool"; agents_ok=0 ;; esac
		# An agent that can start the adjudicator must not start it when its
		# brief says the caller adjudicates; the brief's check below reports it.
		body "$f" | sed '/^## Review protocol$/,$d' | grep -qF 'Unless your brief says the caller adjudicates' || {
			fail "$name starts the adjudicator even when its brief says the caller adjudicates"
			brief_ok=0
		}
	fi
	grep -qx 'omitClaudeMd: true' "$tmp/fm" || { fail "$name lacks omitClaudeMd: true"; agents_ok=0; }
	body "$f" | sed '/^## Review protocol$/,$d' | grep -qF "\`$name.md\`" || {
		fail "$name doesn't name its report file, \`$name.md\`, above the review protocol"
		agents_ok=0
	}
	sed -n '/^## Review protocol$/,$p' "$f" >"$tmp/protocol"
	cmp -s "$tmp/protocol" scripts/review-protocol.md || {
		fail "$name's review protocol differs from scripts/review-protocol.md; edit that file and run sh scripts/sync-protocol.sh"
		agents_ok=0
	}
done
[ "$agents_ok" = 1 ] && pass "agents: tools, omitClaudeMd, report file names and the review protocol's source"

# An agent that denies Playwright MCP tools must deny each one under both the
# bare server name `mcp__playwright__` and the plugin-bundled
# `mcp__plugin_playwright_playwright__`, since a user can add the server either
# way; an exact-name deny list that names a tool under only one prefix fails
# open on the other.
pw_ok=1
for f in agents/*.md; do
	name=${f#agents/}
	name=${name%.md}
	denied=$(frontmatter "$f" | sed -n 's/^disallowedTools:[[:space:]]*//p' | tr ', \t' '\n\n\n' | grep -E '^mcp__(playwright|plugin_playwright_playwright)__')
	[ -n "$denied" ] || continue
	printf '%s\n' "$denied" | sed -n 's/^mcp__playwright__//p' | sort -u >"$tmp/pw1"
	printf '%s\n' "$denied" | sed -n 's/^mcp__plugin_playwright_playwright__//p' | sort -u >"$tmp/pw2"
	only1=$(comm -23 "$tmp/pw1" "$tmp/pw2" | tr '\n' ' ')
	only2=$(comm -13 "$tmp/pw1" "$tmp/pw2" | tr '\n' ' ')
	[ -z "$only1" ] || { fail "$name denies under mcp__playwright__ but not mcp__plugin_playwright_playwright__: $only1"; pw_ok=0; }
	[ -z "$only2" ] || { fail "$name denies under mcp__plugin_playwright_playwright__ but not mcp__playwright__: $only2"; pw_ok=0; }
done
[ "$pw_ok" = 1 ] && pass "Playwright tool denials name each tool under both server prefixes"

# Orchestrate review tells each reviewer that it adjudicates, so the same
# finding isn't adjudicated once per reviewer; the protocol, and every agent
# with the Agent tool (checked in the loop above), must recognize that brief.
grep -qF "The caller adjudicates: don't start the adjudicator." skills/orchestrate-review/SKILL.md || {
	fail "skills/orchestrate-review/SKILL.md no longer gives reviewers the sentence \"The caller adjudicates: don't start the adjudicator.\""
	brief_ok=0
}
grep -qF 'When your brief says the caller adjudicates' scripts/review-protocol.md || {
	fail "scripts/review-protocol.md no longer says what to do when the brief says the caller adjudicates"
	brief_ok=0
}
[ "$brief_ok" = 1 ] && pass "reviewers leave adjudication to orchestrate-review when its brief says so"

# Agents cite the review protocol's steps by number, as in "the copy from step
# 7 of the review protocol", so its nine steps keep their numbers and opening
# words. To renumber or rename one, first update each agent that cites it.
steps=$(sed -n 's/^\*\*\([0-9][0-9]*\. [^*]*\)\*\*.*/\1/p' scripts/review-protocol.md | sed 's/\.$//')
want=$(printf '%s\n' '1. Make a scratch folder' '2. Record the starting state' '3. Find the base' '4. Read the change' \
	'5. Read the guidance yourself' "6. Decide whether you may run the change's code" '7. Experiment only in a copy' '8. Finish' \
	'9. Save the report to a file')
if [ "$steps" = "$want" ]; then
	pass "the review protocol keeps the nine numbered steps the agents cite"
else
	fail "scripts/review-protocol.md's numbered steps changed, but the agents cite them by number: update each agent that cites a moved or renamed step, then this check's list. Steps now: $(printf '%s' "$steps" | tr '\n' '|')"
fi

# Every knackpack:<name> and `<name>-reviewer` in the docs, agents, skills and
# eval cases is an agent or skill that exists (or, for the second form, an eval
# tag), since Claude Code has no alias for an old agent name. A name in plain
# prose, without either form, isn't caught.
refs_ok=1
eval_tags=" $(sed -n 's/^tags:[[:space:]]*\[\(.*\)\][[:space:]]*$/\1/p' evals/*/prompt.md | tr ',' ' ' | tr -s ' \n' '  ') "
for ref in $(grep -rhoE --exclude-dir=results 'knackpack:[a-z0-9-]+|`[a-z0-9-]+-reviewer`' README.md .claude/CLAUDE.md agents skills evals | sort -u); do
	name=$(printf '%s' "$ref" | tr -d '`' | sed 's/^knackpack://')
	[ -f "agents/$name.md" ] || [ -d "skills/$name" ] && continue
	case $ref in knackpack:*) ;; *) case $eval_tags in *" $name "*) continue ;; esac ;; esac
	fail "$ref is mentioned, but no agent or skill has that name"
	refs_ok=0
done
[ "$refs_ok" = 1 ] && pass "mentions of knackpack's agents and skills name ones that exist"

# Keys: Claude Code ignores a frontmatter or hook key it doesn't know without
# a word, so one that isn't documented fails here. Plugin agents can't use
# hooks, mcpServers, permissionMode or initialPrompt, so those fail too.
skill_keys='name description when_to_use argument-hint arguments disable-model-invocation user-invocable allowed-tools disallowed-tools model effort context agent background hooks paths shell metadata license compatibility'
agent_keys='name description tools disallowedTools model maxTurns autoCompactWindow skills memory background omitClaudeMd effort isolation color experimental'
unknown_keys() { # <file> <keys>
	frontmatter "$1" | sed -n 's/^\([^[:space:]#][^:]*\):.*/\1/p' | while read -r k; do
		case " $2 " in *" $k "*) ;; *) printf '%s ' "$k" ;; esac
	done
}
keys_ok=1
for f in skills/*/SKILL.md; do
	bad=$(unknown_keys "$f" "$skill_keys")
	[ -z "$bad" ] || { fail "$f has frontmatter keys Claude Code doesn't know: $bad"; keys_ok=0; }
done
for f in agents/*.md; do
	bad=$(unknown_keys "$f" "$agent_keys")
	[ -z "$bad" ] || { fail "$f has frontmatter keys a plugin agent can't use: $bad"; keys_ok=0; }
done
if ! command -v jq >/dev/null 2>&1; then
	fail "jq isn't installed, so hooks/hooks.json wasn't checked"
	keys_ok=0
else
	bad=$(jq -r '
		(keys - ["description", "hooks"])[],
		(.hooks | keys - ["SessionStart", "Setup", "UserPromptSubmit", "UserPromptExpansion", "PreToolUse", "PermissionRequest", "PermissionDenied", "PostToolUse", "PostToolUseFailure", "PostToolBatch", "Notification", "MessageDisplay", "SubagentStart", "SubagentStop", "TaskCreated", "TaskCompleted", "Stop", "StopFailure", "TeammateIdle", "InstructionsLoaded", "ConfigChange", "CwdChanged", "DirectoryAdded", "FileChanged", "WorktreeCreate", "WorktreeRemove", "PreCompact", "PostCompact", "PreModelSwitch", "PostModelSwitch", "Elicitation", "ElicitationResult", "SessionEnd"])[],
		(.hooks[][] | keys - ["matcher", "hooks"])[],
		(.hooks[][].hooks[] | keys - ["type", "command", "args", "timeout", "if", "statusMessage", "once", "async", "asyncRewake", "shell", "onFailure"])[]
	' hooks/hooks.json 2>&1 | tr '\n' ' ')
	[ -z "$bad" ] || { fail "hooks/hooks.json has keys Claude Code doesn't know: $bad"; keys_ok=0; }
fi
[ "$keys_ok" = 1 ] && pass "frontmatter and hooks.json keys"

# The README's counts of skills, agents and hooks.
words='one two three four five six seven eight nine ten eleven twelve'
word() { set -- "$1" $words; i=$1; shift; [ "$i" -ge 1 ] && [ "$i" -le 12 ] && eval "printf '%s' \"\${$i}\"" || printf '%s' "$i"; }
skills_n=$(find skills -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
hooks_n=$(jq '.hooks | length' hooks/hooks.json 2>/dev/null)
counts_ok=1
grep -oiE "(^|[^a-z])($(printf '%s' "$words" | tr ' ' '|')) (skills|review agents|agents|hooks)" README.md | sed 's/^[^a-zA-Z]*//' >"$tmp/counts"
while read -r w noun rest; do
	case $noun in skills) want=$(word "$skills_n") ;; review | agents) want=$(word "$n") ;; hooks) want=$(word "$hooks_n") ;; esac
	[ "$(printf '%s' "$w" | tr '[:upper:]' '[:lower:]')" = "$want" ] || { fail "README says \"$w $noun${rest:+ $rest}\", but there are $want"; counts_ok=0; }
done <"$tmp/counts"
[ -s "$tmp/counts" ] || { fail "README names no counts of skills, agents or hooks"; counts_ok=0; }
[ "$counts_ok" = 1 ] && pass "README counts: $skills_n skills, $n agents, $hooks_n hooks"

# No email addresses but reserved example ones, in tracked files and in new
# files not added yet.
emails=$(git ls-files -z --cached --others --exclude-standard | xargs -0 grep -hoE '[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}' 2>/dev/null |
	grep -vE '@example\.(com|org|net)$|^git@github\.com$' | sort -u | tr '\n' ' ')
if [ -n "$emails" ]; then fail "email addresses in files git tracks or would add: $emails"; else pass "no email addresses"; fi

# Every eval case loads and is complete: a prompt, frontmatter and grader keys
# from the documented lists (the runner rejects an unknown key, but only once
# the run starts), a fixture that exists and parses, grader regexes that
# compile as JavaScript, and at least one grader, so a half-written case fails
# here and not half an hour into a run.
case_keys='schema_version name description tags plugins runs expected_outcome model max_turns timeout_seconds allowed_tools append_system_prompt env'
yaml_keys='schema_version name description tags plugins runs expected_outcome context scaffold_script history_file add_dirs execution prompt model max_turns timeout_seconds allowed_tools append_system_prompt env graders'
grader_keys='type weight arm pattern flags match target tool input_match min max before after path exists criteria focus baseline_file'
grader_types='regex tool_used tool_order file_exists llm baseline'
# A YAML scalar without its quotes or, when unquoted, its trailing comment.
# (BSD sed reads a label to the end of the line, so `b` gets its own -e.)
unquote() {
	sed -e '/^"/{' -e 's/^\("[^"]*"\).*/\1/' -e 's/^"//' -e 's/"$//' -e b -e '}' \
		-e "/^'/{" -e "s/^\\('.*'\\)[^']*\$/\\1/" -e "s/^'//" -e "s/'\$//" -e "s/''/'/g" -e b -e '}' \
		-e 's/[[:space:]]#.*$//' -e 's/[[:space:]]*$//'
}
value() { sed -n "s/^[[:space:]]*$1:[[:space:]]*//p" | unquote; } # <key>, at any depth, from YAML on stdin
# Frontmatter keys whose plain, unquoted value holds ": " or ends in ":", which
# YAML can't parse; the runner then refuses to load the case and runs the rest
# without it.
colon_values() {
	frontmatter "$1" | awk '/^[A-Za-z_][A-Za-z0-9_]*:[[:space:]]/ {
		v = $0; sub(/^[^:]*:[[:space:]]*/, "", v)
		if (v !~ /^["\047[{|>]/ && v ~ /: |:$/) { k = $0; sub(/:.*/, "", k); printf "%s ", k }
	}'
}
unknown_yaml_keys() { # <file> <keys>: keys at any depth that aren't in the list, skipping block scalars
	awk '
		function indent(s) { match(s, /^ */); return RLENGTH }
		inblock && (NF == 0 || indent($0) > bi) { next }
		{ inblock = 0 }
		/^ *(- +)?[A-Za-z_][A-Za-z0-9_]*:/ {
			k = $0; sub(/^ *(- +)?/, "", k); sub(/:.*/, "", k); print k
			if ($0 ~ /: *[|>][-+0-9]* *(#.*)?$/) { inblock = 1; bi = indent($0) }
		}' "$1" | while read -r k; do
		case " $2 " in *" $k "*) ;; *) printf '%s ' "$k" ;; esac
	done
}
have_bash=; command -v bash >/dev/null 2>&1 && have_bash=1
have_node=; command -v node >/dev/null 2>&1 && have_node=1
evals_ok=1
for d in evals/*/; do
	c=${d%/}
	[ "$c" = evals/results ] && continue
	[ -f "$c/prompt.md" ] || [ -f "$c/case.yaml" ] || { fail "$c has neither prompt.md nor case.yaml"; evals_ok=0; continue; }
	if [ -f "$c/prompt.md" ]; then
		bad=$(unknown_keys "$c/prompt.md" "$case_keys")
		[ -z "$bad" ] || { fail "$c/prompt.md has frontmatter keys claude plugin eval doesn't know: $bad"; evals_ok=0; }
		bad=$(colon_values "$c/prompt.md")
		[ -z "$bad" ] || { fail "$c/prompt.md has unquoted values holding \": \" or ending in \":\", which YAML can't parse: $bad"; evals_ok=0; }
		[ -n "$(body "$c/prompt.md" | tr -d '[:space:]')" ] || grep -q '^[[:space:]]*prompt:' "$c/case.yaml" 2>/dev/null || { fail "$c has no prompt"; evals_ok=0; }
	else
		grep -q '^[[:space:]]*prompt:' "$c/case.yaml" || { fail "$c has no prompt"; evals_ok=0; }
	fi
	if [ -f "$c/case.yaml" ]; then
		bad=$(unknown_yaml_keys "$c/case.yaml" "$yaml_keys $grader_keys")
		[ -z "$bad" ] || { fail "$c/case.yaml has keys claude plugin eval doesn't know: $bad"; evals_ok=0; }
		fixture=$(value scaffold_script <"$c/case.yaml")
		if [ -n "$fixture" ]; then
			if [ ! -f "$c/$fixture" ]; then fail "$c/case.yaml names a fixture that doesn't exist: $fixture"; evals_ok=0
			elif [ -n "$have_bash" ] && ! bash -n "$c/$fixture" 2>"$tmp/err"; then fail "$c/$fixture doesn't parse: $(head -c 200 "$tmp/err")"; evals_ok=0
			fi
		fi
	fi
	if [ -z "$(ls "$c"/graders/*.md 2>/dev/null)" ] && ! grep -q '^graders:' "$c/case.yaml" 2>/dev/null; then fail "$c has no graders"; evals_ok=0; fi
	for g in "$c"/graders/*.md; do
		[ -f "$g" ] || continue
		t=$(frontmatter "$g" | value type)
		case " $grader_types " in *" $t "*) ;; *) fail "$g has type '$t', not one of: $grader_types"; evals_ok=0 ;; esac
		# Each type's own key, without which the grader can't grade.
		case $t in
		regex) need=pattern ;; tool_used) need=tool ;; tool_order) need="before after" ;; file_exists) need=path ;; baseline) need=baseline_file ;; *) need= ;;
		esac
		for k in $need; do
			[ -n "$(frontmatter "$g" | value "$k")" ] || { fail "$g is a $t grader without $k"; evals_ok=0; }
		done
		if [ "$t" = llm ] && [ -z "$(frontmatter "$g" | value criteria)" ] && [ -z "$(body "$g" | tr -d '[:space:]')" ]; then
			fail "$g is an llm grader with no criteria and an empty body"; evals_ok=0
		fi
		bad=$(unknown_keys "$g" "$grader_keys")
		[ -z "$bad" ] || { fail "$g has keys claude plugin eval doesn't know: $bad"; evals_ok=0; }
		bad=$(colon_values "$g")
		[ -z "$bad" ] || { fail "$g has unquoted values holding \": \" or ending in \":\", which YAML can't parse: $bad"; evals_ok=0; }
		a=$(frontmatter "$g" | value arm)
		case $a in ''|with-only|both) ;; *) fail "$g has arm '$a', not with-only or both"; evals_ok=0 ;; esac
		for k in target focus; do
			v=$(frontmatter "$g" | value "$k")
			case $v in ''|last_message|trace|files|mock_calls|'{'*source:*file*,*path:*'}') ;; *) fail "$g has $k '$v', which isn't a documented value"; evals_ok=0 ;; esac
		done
		if [ -n "$have_node" ]; then
			for k in pattern input_match; do
				v=$(frontmatter "$g" | value "$k")
				[ -z "$v" ] || P="$v" node -e 'new RegExp(process.env.P)' 2>/dev/null || { fail "$g's $k isn't a valid JavaScript regex: $v"; evals_ok=0; }
			done
		fi
	done
done
note=
[ -n "$have_bash" ] || note="$note, fixtures not parsed: no bash"
[ -n "$have_node" ] || note="$note, regexes not compiled: no node"
[ "$evals_ok" = 1 ] && pass "eval cases: $(find evals -mindepth 1 -maxdepth 1 -type d ! -name results ! -name '.*' | wc -l | tr -d ' ') complete$note"

# Skill sizes: compaction keeps about the first 5,000 tokens of each skill.
for f in skills/*/SKILL.md; do
	c=$(chars <"$f")
	[ "$c" -lt 19000 ] || fail "$f is $c characters, over 19,000"
done
c=$(body skills/track-intent/SKILL.md | chars)
if [ "$c" -lt 8500 ]; then pass "skill sizes (track-intent body $c characters)"; else fail "track-intent's body is $c characters, over 8,500"; fi

# Text the hook relies on, as the skills write it. The skills that save files
# use one fallback folder, in the same words, and the hook tests below take its
# name from them: the hook leaves that folder out of a turn's work and looks
# there for the checkpoint after a compaction. The record layout holds the
# strings the hook reads a record by.
contract_ok=1
IFS= read -r save_folder <<'EOF'
the session scratchpad named in your system prompt, if there is one. Otherwise run `printenv TMPDIR` once (use `/tmp` if it prints nothing) and use the folder `claude-${CLAUDE_SESSION_ID}` inside it, writing the folder's full path literally in every later command. Create it with `mkdir -p -m 700 <folder>`, then check it with `[ -d <folder> ] && [ ! -L <folder> ] && [ -O <folder> ] && chmod 700 <folder>`; if the check fails, stop and tell the user.
EOF
for name in challenge-requirements checkpoint handoff orchestrate-review plan-implementation research; do
	grep -qF -- "$save_folder" "skills/$name/SKILL.md" ||
		{ fail "skills/$name/SKILL.md doesn't name its save folder in the words check.sh holds, which the hook relies on"; contract_ok=0; }
done
fallback=$(printf '%s\n' "$save_folder" | sed -n 's/.*`\([A-Za-z0-9._-]*\)${CLAUDE_SESSION_ID}`.*/\1/p')
[ -n "$fallback" ] || { fail "check.sh's save-folder words name no folder for the hook tests"; contract_ok=0; }
layout=$(sed -n '/^```markdown$/,/^```$/p' skills/track-intent/SKILL.md)
for s in '# Intent record: ' '- Status: active | paused | stopped | done' '## Assumed' '- ASM-01: <assumption>. Why: ' '## Not agreed' \
	'- PROP-01: <suggestion>, by <developer or Claude>. open | rejected | accepted as REQ-<n> | replaced by PROP-<n>' \
	'## Open questions' '- Q-01: ' '## History'; do
	printf '%s\n' "$layout" | grep -qF -- "$s" || { fail "track-intent's record layout no longer has \"$s\", which the hook reads"; contract_ok=0; }
done
[ "$contract_ok" = 1 ] && pass "the skills' save folder and record layout match what the hook reads"

# The hook, under every shell at hand: silent, always exit 0, and its rules
# output under the 10,000-character cap even with long paths.
command -v dash >/dev/null 2>&1 || fail "dash isn't installed, so the hook can't be tested under it"
shells=
for s in dash sh bash; do command -v "$s" >/dev/null 2>&1 && shells="$shells $s"; done
# The paths the hook prints have fixed lengths, whatever the checkout's and
# TMPDIR's, so the size checks measure the same everywhere. The hook prints its
# own root, resolved with pwd -P, so it runs from a copy of the files it reads
# at a 100-character root, longer than an installed copy's (about 68), and the
# state folder and project sit in a folder of 172 characters. Each is built on
# the resolved TMPDIR, since git resolves the project's path too.
pad() { awk -v n="$1" -v min="$2" 'BEGIN { if (n < min) n = min; while (n-- > 0) printf "a" }'; } # <length> <minimum>
real=$(CDPATH='' cd -- "$tmp" && pwd -P)
plug=$real/$(pad $((99 - ${#real})) 1)
hook=$plug/hooks/track-intent.sh
mkdir -p "$plug/hooks" "$plug/skills/track-intent" "$plug/.claude-plugin" && cp hooks/track-intent.sh "$plug/hooks/" &&
	cp skills/track-intent/SKILL.md "$plug/skills/track-intent/" && cp .claude-plugin/plugin.json "$plug/.claude-plugin/" ||
	fail "couldn't copy the hook to test it"
# A repository's records folder is named after a cksum of its path, 1 to 10
# digits long, so the last letter is the first that gives all 10.
long=$real/$(pad $((170 - ${#real})) 19)
for c in b c d e f g h i j k l m n o p q r s t u v w x y z; do
	h=$(printf '%s' "$long$c/project/.git" | cksum | cut -d ' ' -f 1)
	[ "${#h}" = 10 ] && break
done
long=$long$c
mkdir -p "$long/project" "$long/state" "$tmp/home"
# The project is a git repository with a worktree, as most users' are, and
# HOME is a fresh folder, so the user's git config doesn't apply. Both come
# back before the version check, which needs the user's git ignores.
real_home=$HOME
nosystem=${GIT_CONFIG_NOSYSTEM-}
export HOME="$tmp/home" GIT_CONFIG_NOSYSTEM=1
git -C "$long/project" init -q && git -C "$long/project" -c user.name=check -c user.email=check@example.com commit -q --allow-empty -m init &&
	git -C "$long/project" worktree add -q "$long/worktree" 2>/dev/null || fail "couldn't make a git repository and worktree to test the hook in"
sid=00000000-0000-0000-0000-000000000000
run() { # <shell> <mode> <event> [state] [project]
	printf '%s' "$3" | env -u KNACKPACK_INTENT -u CLAUDE_CODE_ENTRYPOINT CLAUDE_CODE_SESSION_ATTENDED=1 \
		XDG_STATE_HOME="${4:-$long/state}" CLAUDE_PROJECT_DIR="${5:-$long/project}" \
		"$1" "$hook" "$2" >"$tmp/out" 2>"$tmp/err"
	code=$?
	if [ "$code" != 0 ] || [ -s "$tmp/err" ]; then
		fail "hook $2 under $1: exit $code, stderr: $(head -c 200 "$tmp/err")"
		return 1
	fi
}
event="{\"session_id\":\"$sid\",\"source\":\"startup\",\"prompt\":\"hi\",\"tool_input\":{\"file_path\":\"$long/project/a.md\"},\"last_assistant_message\":\"Noted: x\"}"
# The end of a turn whose final message claims nothing, and a final message.
done_event="{\"session_id\":\"$sid\",\"stop_hook_active\":false,\"last_assistant_message\":\"Done.\"}"
said() { printf '{"session_id":"%s","stop_hook_active":false,"last_assistant_message":"%s"}' "$sid" "$1"; }
version=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' .claude-plugin/plugin.json)
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
		if [ "$m" = stop ] && ! jq -e '.hookSpecificOutput.additionalContext | type == "string"' "$tmp/out" >/dev/null 2>&1; then
			fail "hook stop under $s printed something other than its JSON: $(head -c 200 "$tmp/out")"
			hook_ok=0
		fi
		if [ "$m" = rules ]; then
			size=$(wc -c <"$tmp/out" | tr -d ' ')
			if grep -q 'too long to print here' "$tmp/out"; then
				fail "hook rules output passed 9,900 bytes with a ${#plug}-character plugin root and ${#long}-character paths, so the hook printed its pointer instead; shorten the track-intent body"
				hook_ok=0
			elif [ "$size" -gt 9900 ]; then
				fail "hook rules output is $size bytes with a ${#plug}-character plugin root and ${#long}-character paths; keep it under 9,900"
				hook_ok=0
			fi
			# A compaction can re-attach an older copy of the skill, so the
			# rules say which version they are.
			head -n 1 "$tmp/out" | grep -qF "from knackpack $version, replace any older copy" ||
				{ fail "hook rules under $s don't start with the plugin's version: $(head -n 1 "$tmp/out")"; hook_ok=0; }
		fi
	done
	run "$s" prompt '' || hook_ok=0
	# Files skills save in Claude Code's scratchpad or knackpack's fallback
	# folder don't count as work.
	for f in "/tmp/claude-501/-proj/$sid/scratchpad/PLAN.md" "/tmp/$fallback$sid/PLAN.md"; do
		run "$s" prompt "$event" && run "$s" tool "{\"session_id\":\"$sid\",\"tool_input\":{\"file_path\":\"$f\"}}" &&
			run "$s" stop "$done_event" && run "$s" prompt "$event" || hook_ok=0
		if grep -q 'edited files but not the record' "$tmp/out"; then
			fail "hook under $s counts a file saved to $f as work"
			hook_ok=0
		fi
	done
	# Updating the record counts as a record edit, also when the state path
	# isn't in the normalized form Claude Code hands hooks, and a look-alike
	# path beside the record doesn't.
	rec=$(env XDG_STATE_HOME="$long/state" "$s" "$hook" manual "$sid" "$long/project" 2>/dev/null | sed -n 's/^- Current record: `\(.*\)` .*/\1/p')
	[ -n "$rec" ] || { fail "hook manual under $s doesn't print the record's path"; hook_ok=0; }
	for st in "$long/state" "$long/state/" "$long//state" "$long/./state" "/$long/state"; do
		run "$s" prompt "$event" "$st" && run "$s" tool "{\"session_id\":\"$sid\",\"tool_input\":{\"file_path\":\"$rec\"}}" "$st" && run "$s" stop "$event" "$st" || hook_ok=0
		if [ -s "$tmp/out" ]; then
			fail "hook under $s with XDG_STATE_HOME=$st doesn't count an update of the record as one: $(head -c 200 "$tmp/out")"
			hook_ok=0
		fi
		run "$s" prompt "$event" "$st" || hook_ok=0
		if grep -q 'edited files but not the record' "$tmp/out"; then
			fail "hook under $s with XDG_STATE_HOME=$st reports a record update as a missed one"
			hook_ok=0
		fi
	done
	run "$s" prompt "$event" && run "$s" tool "{\"session_id\":\"$sid\",\"tool_input\":{\"file_path\":\"$rec-notes.txt\"}}" && run "$s" stop "$event" || hook_ok=0
	if ! grep -q "record wasn't updated" "$tmp/out"; then
		fail "hook under $s counts an edit of a file named after the record as a record update"
		hook_ok=0
	fi
	# A record changed with a shell command still counts as updated, and a
	# plain claim of an update that didn't happen is caught like "Noted:".
	run "$s" prompt "$event" && printf '%s\n' '- 2026-10-30: changed by a shell command' >>"$rec" && run "$s" stop "$event" || hook_ok=0
	[ -s "$tmp/out" ] && { fail "hook under $s doesn't see a record update made with a shell command"; hook_ok=0; }
	# A file named after the session that isn't a record doesn't count.
	run "$s" prompt "$event" && printf '%s\n' 'a note' >>"${rec%.md}.notes.md" && run "$s" stop "$event" || hook_ok=0
	grep -q "record wasn't updated" "$tmp/out" || { fail "hook under $s counts a change to $sid.notes.md as a record update"; hook_ok=0; }
	rm -f "${rec%.md}.notes.md"
	for claim in 'I have recorded this as an open proposal.' 'I added it to the intent record.' 'Noted it under Open questions.'; do
		run "$s" prompt "$event" && run "$s" stop "$(said "$claim")" || hook_ok=0
		grep -q "record wasn't updated" "$tmp/out" || { fail "hook under $s misses a claimed record update in plain words: $claim"; hook_ok=0; }
	done
	# Records of other kinds aren't the intent record, and only Claude's final
	# message counts, not another field such as a background task's.
	for claim in 'The provider added it to the record set.' "I recorded it as an open question in the report's section D." 'I added that to the records table.'; do
		run "$s" prompt "$event" && run "$s" stop "$(said "$claim")" || hook_ok=0
		[ -s "$tmp/out" ] && { fail "hook under $s reads \"$claim\" as a claimed update of the intent record"; hook_ok=0; }
	done
	run "$s" prompt "$event" && run "$s" stop "{\"session_id\":\"$sid\",\"last_assistant_message\":\"Done.\",\"background_tasks\":[{\"description\":\"Noted: x\"}]}" || hook_ok=0
	[ -s "$tmp/out" ] && { fail "hook under $s reads a claimed update outside Claude's final message"; hook_ok=0; }
	# A subagent's edit, which carries the session's ID too, isn't this
	# conversation's.
	run "$s" prompt "$event" && run "$s" tool "{\"session_id\":\"$sid\",\"agent_id\":\"a1\",\"agent_type\":\"Explore\",\"tool_input\":{\"file_path\":\"$long/project/a.md\"}}" &&
		run "$s" stop "$done_event" && run "$s" prompt "$event" || hook_ok=0
	grep -q 'edited files but not the record' "$tmp/out" && { fail "hook under $s counts a subagent's edit as this conversation's"; hook_ok=0; }
	# A message queued while Claude works runs the prompt hook mid-turn. The
	# turn's record update still counts at Stop, and its edits aren't flagged
	# until the turn ends.
	run "$s" prompt "$event" && run "$s" tool "{\"session_id\":\"$sid\",\"tool_input\":{\"file_path\":\"$rec\"}}" &&
		run "$s" prompt "$event" && run "$s" stop "$event" || hook_ok=0
	[ -s "$tmp/out" ] && { fail "hook under $s forgets a record update made before a message queued mid-turn"; hook_ok=0; }
	run "$s" prompt "$event" && run "$s" tool "{\"session_id\":\"$sid\",\"tool_input\":{\"file_path\":\"$long/project/a.md\"}}" && run "$s" prompt "$event" || hook_ok=0
	grep -q 'edited files but not the record' "$tmp/out" && { fail "hook under $s flags a turn's edits while the turn is still running"; hook_ok=0; }
	run "$s" stop "$done_event" && run "$s" prompt "$event" || hook_ok=0
	grep -q 'edited files but not the record' "$tmp/out" || { fail "hook under $s misses a finished turn that edited files but not the record"; hook_ok=0; }
	# A background-task notification gets a short note, not the full reminder.
	run "$s" prompt "$(printf '%s' "$event" | sed 's/"prompt":"hi"/"prompt":"<task-notification>\\n<status>completed<\/status>"/')" || hook_ok=0
	{ grep -q 'background-task notification' "$tmp/out" && ! grep -q 'before acting' "$tmp/out"; } ||
		{ fail "hook under $s gives a background-task notification the full reminder"; hook_ok=0; }
	# The current record is the one edited last, not the highest-numbered.
	two=${rec%.md}.2.md
	printf '%s\n' '# Intent record: side task' >"$two" && touch -t 202601010000 "$two" && printf '%s\n' '- edited' >>"$rec"
	run "$s" prompt "$event" || hook_ok=0
	grep -qF "Record: $rec (exists)" "$tmp/out" || { fail "hook under $s doesn't treat the record edited last as the current one"; hook_ok=0; }
	printf '%s\n' '- edited' >>"$two"
	run "$s" prompt "$event" || hook_ok=0
	grep -qF "Record: $two (exists)" "$tmp/out" || { fail "hook under $s doesn't switch to the record edited last"; hook_ok=0; }
	grep -qF "Other records of this session that aren't done: $rec (" "$tmp/out" || { fail "hook under $s doesn't name the session's other record that isn't done"; hook_ok=0; }
	# A side task's record that's done gives way to one that isn't, even when
	# it was edited last.
	printf '%s\n' '- Status: done · Updated: 2026-10-30' >>"$two"
	run "$s" prompt "$event" || hook_ok=0
	grep -qF "Record: $rec (exists)" "$tmp/out" || { fail "hook under $s keeps a finished side task's record current"; hook_ok=0; }
	grep -q '^Other records' "$tmp/out" && { fail "hook under $s names a finished side task's record among those not done"; hook_ok=0; }
	rm -f "$two"
	# Run from another folder than the session's repository, as a manual run
	# can be, the hook finds the session's record by its ID, says so, and
	# counts an update of it. With two folders holding one, it doesn't guess.
	printf '%s\n' '# Intent record: test' '' '## Open questions' '- Q-14: still open' >"$rec"
	away=$real/away
	mkdir -p "$away"
	run "$s" prompt "$event" "" "$away" || hook_ok=0
	grep -qxF "Record: $rec (exists, found by its session ID: the working directory has left the session's repository). Open questions: Q-14." "$tmp/out" ||
		{ fail "hook prompt under $s, outside the session's repository, doesn't find its record: $(grep '^Record:' "$tmp/out")"; hook_ok=0; }
	(cd "$away" && env XDG_STATE_HOME="$long/state" "$s" "$hook" manual "$sid") >"$tmp/out" 2>/dev/null
	{ grep -qF -- "- Current record: \`$rec\` (exists, found by its session ID" "$tmp/out" && grep -q '^- This repository.s team glossary: unknown' "$tmp/out"; } ||
		{ fail "hook manual under $s, run from another folder, doesn't find the session's record: $(grep 'Current record' "$tmp/out")"; hook_ok=0; }
	run "$s" stop "$done_event" "" "$away" && run "$s" prompt "$event" "" "$away" &&
		run "$s" tool "{\"session_id\":\"$sid\",\"tool_input\":{\"file_path\":\"$rec\"}}" "" "$away" && run "$s" stop "$event" "" "$away" || hook_ok=0
	[ -s "$tmp/out" ] && { fail "hook under $s, outside the session's repository, doesn't count an update of its record"; hook_ok=0; }
	mkdir -p "$long/state/knackpack/intent/other-1" && cp "$rec" "$long/state/knackpack/intent/other-1/$sid.md"
	run "$s" prompt "$event" "" "$away" || hook_ok=0
	grep -q "^Record: .*/away-[0-9]*/$sid\\.md (not created yet)\\.\$" "$tmp/out" ||
		{ fail "hook prompt under $s picks one of two folders holding the session's record: $(grep '^Record:' "$tmp/out")"; hook_ok=0; }
	rm -rf "$away" "$long/state/knackpack/intent/other-1" "$long/state/knackpack/intent"/away-*
	# With `..` after a symbolic link, the folder the hook checks and the folder
	# its normalized path names differ; it must check the second one too and
	# never write through a link.
	rm -rf "$tmp/sym"
	mkdir -p "$tmp/sym/real/x" "$tmp/sym/elsewhere" "$tmp/sym/st/knackpack" && ln -s "$tmp/sym/real/x" "$tmp/sym/link" && ln -s "$tmp/sym/elsewhere" "$tmp/sym/st/knackpack/intent" || fail "couldn't set up the symbolic links to test the hook with"
	run "$s" prompt "$event" "$tmp/sym/link/../st" || hook_ok=0
	if [ -n "$(find "$tmp/sym/elsewhere" -mindepth 1 2>/dev/null)" ]; then
		fail "hook under $s wrote through a symbolic link when the state path has .. after a link"
		hook_ok=0
	fi
	# A worktree shares its repository's records.
	for d in project worktree; do
		env XDG_STATE_HOME="$long/state" "$s" "$hook" manual "$sid" "$long/$d" 2>/dev/null | grep "records:" >"$tmp/$d.records"
	done
	if [ ! -s "$tmp/project.records" ] || ! cmp -s "$tmp/project.records" "$tmp/worktree.records"; then
		fail "hook under $s gives a worktree other records than its repository: $(cat "$tmp/project.records" "$tmp/worktree.records")"
		hook_ok=0
	fi
	# Off, or in a session nobody attends, it prints nothing and writes nothing.
	for v in CLAUDE_CODE_SESSION_ATTENDED=0 'CLAUDE_CODE_SESSION_ATTENDED=1 KNACKPACK_INTENT=off' CLAUDE_CODE_ENTRYPOINT=sdk-cli; do
		rm -rf "$tmp/quiet"
		for m in rules state prompt tool stop; do
			# shellcheck disable=SC2086 # $v holds one or two assignments
			printf '%s' "$event" | env -u KNACKPACK_INTENT -u CLAUDE_CODE_SESSION_ATTENDED -u CLAUDE_CODE_ENTRYPOINT $v \
				XDG_STATE_HOME="$tmp/quiet" CLAUDE_PROJECT_DIR="$long/project" "$s" "$hook" "$m" >>"$tmp/quiet.out" 2>&1
		done
		if [ -s "$tmp/quiet.out" ] || [ -e "$tmp/quiet" ]; then
			fail "hook under $s with $v printed or wrote something: $(head -c 200 "$tmp/quiet.out" | tr '\n' ' ')"
			hook_ok=0
		fi
		rm -f "$tmp/quiet.out"
	done
	# Open proposals: a status follows "by <who>. ", or a full stop, "?" or "!"
	# with or without a closing quote, and a reason may follow it. Accepted and
	# replaced ones are settled. A proposal without a status is named, not
	# dropped.
	for d in "$long/state/knackpack/intent"/*/; do
		printf '%s\n' '# Intent record: test' '' '## Not agreed' \
			'- PROP-01: Reopen the rejected ticket, by Claude. open' \
			'- PROP-02: Wraps onto' '  a second line, by Claude. open (asked twice)' \
			'- PROP-03: Keep the open flag, by Claude. rejected' \
			'- PROP-04: Add a cache, by Claude. rejected for now: leaves it open' \
			'- PROP-05: Keep it, by Claude. open (raised again, by the developer)' \
			'- PROP-06: Add it, by Claude. rejected: too slow. Open questions moved.' \
			'- PROP-07: "Would it taste better?" open' \
			'- PROP-08: "Add it to everything." open (research first)' \
			'- PROP-09: "Drop the cache." rejected' \
			'- PROP-10: Add a queue (open)' \
			'- PROP-11: Queue the exports, by Claude. accepted as REQ-43 (REQ-33, REQ-32); its wording is in History' \
			'- PROP-12: Cache the totals, by Claude. replaced by PROP-13' \
			'- PROP-13: Cache the totals per day, by the developer. open' \
			'- PROP-14: "Ship it as it is." Accepted as REQ-44' >"$d$sid.md"
	done
	run "$s" prompt "$event" || hook_ok=0
	grep -q 'Open proposals: PROP-01, PROP-02, PROP-05, PROP-07, PROP-08, PROP-13\. Proposals with no status the hook can read: PROP-10\.$' "$tmp/out" ||
		{ fail "hook prompt under $s lists the wrong open proposals: $(grep -o 'Open proposals:.*' "$tmp/out")"; hook_ok=0; }
	# Assumptions, each up to its "Why:": the newest by number in full, within
	# about 1,000 characters, in order of number, and the oldest by ID.
	for d in "$long/state/knackpack/intent"/*/; do
		{
			printf '%s\n' '# Intent record: test' '' '## Assumed (not confirmed)'
			for n in 02 03 04 05 06 07 08 09 11 14 13 19 20 21; do
				printf '%s\n' "- ASM-$n: assumption $n, with enough words to make the entry about one hundred characters. Why: x"
			done
		} >"$d$sid.md"
	done
	run "$s" stop "$done_event" && run "$s" prompt "$event" || hook_ok=0
	got=$(sed -n 's/^- \(ASM-[0-9]*\): assumption [0-9]*, with .* characters\.$/\1/p' "$tmp/out" | tr '\n' ' ')
	{ [ "$got" = 'ASM-05 ASM-06 ASM-07 ASM-08 ASM-09 ASM-11 ASM-13 ASM-14 ASM-19 ASM-20 ASM-21 ' ] &&
		grep -qx 'More in the record: ASM-02, ASM-03, ASM-04\.' "$tmp/out"; } ||
		{ fail "hook prompt under $s doesn't give the newest assumptions in full, by number: $got$(grep 'More in the record' "$tmp/out")"; hook_ok=0; }
	# Later in the same turn, with the records unchanged, the reminder names
	# them by ID only, after the same instruction. A change, or a new turn,
	# lists them again.
	run "$s" prompt "$event" || hook_ok=0
	{ grep -q '^knackpack intent tracking: before acting on this message' "$tmp/out" && ! grep -q '^- ASM-' "$tmp/out" &&
		grep -qx 'Assumed, not confirmed, as an earlier reminder listed them: ASM-02, ASM-03, ASM-04, ASM-05, ASM-06, ASM-07, ASM-08, ASM-09, ASM-11, ASM-13, ASM-14, ASM-19, ASM-20, ASM-21; check this message and your next step against them\.' "$tmp/out"; } ||
		{ fail "hook prompt under $s doesn't name the assumptions by ID only later in a turn: $(grep 'Assumed' "$tmp/out")"; hook_ok=0; }
	printf '%s\n' '- ASM-22: assumption 22, recorded later in the turn. Why: y' >>"$d$sid.md"
	run "$s" prompt "$event" || hook_ok=0
	grep -qx -- '- ASM-22: assumption 22, recorded later in the turn\.' "$tmp/out" ||
		{ fail "hook prompt under $s doesn't list the assumptions again after the record changed in the turn"; hook_ok=0; }
	run "$s" stop "$done_event" && run "$s" prompt "$event" || hook_ok=0
	grep -qx -- '- ASM-22: assumption 22, recorded later in the turn\.' "$tmp/out" ||
		{ fail "hook prompt under $s doesn't list the assumptions again in a new turn"; hook_ok=0; }
	# A newer assumption too long for the space left is cut at a space, not
	# passed over for older, shorter ones, which are named by ID.
	for d in "$long/state/knackpack/intent"/*/; do
		{
			printf '%s\n' '# Intent record: test' '' '## Assumed (not confirmed)'
			for n in 01 02 03 04 05; do printf '%s\n' "- ASM-$n: old assumption $n. Why: x"; done
			awk 'BEGIN { s = "- ASM-06: a long assumption"; while (length(s) < 900) s = s " with more words"; print s " and its end. Why: y" }'
			awk 'BEGIN { s = "- ASM-07: the newest assumption"; while (length(s) < 300) s = s " with more words"; print s ". Why: z" }'
		} >"$d$sid.md"
	done
	run "$s" stop "$done_event" && run "$s" prompt "$event" || hook_ok=0
	{ grep -q '^- ASM-06: a long assumption with more words.* \[\.\.\.\]$' "$tmp/out" && grep -q '^- ASM-07: the newest assumption' "$tmp/out" &&
		! grep -q 'and its end' "$tmp/out" && grep -qx 'More in the record: ASM-01, ASM-02, ASM-03, ASM-04, ASM-05\.' "$tmp/out"; } ||
		{ fail "hook prompt under $s doesn't cut a long newer assumption to keep it ahead of older ones: $(grep -o '^- ASM-0[0-9]' "$tmp/out" | tr '\n' ' ')"; hook_ok=0; }
	rm -f "$long/state/knackpack/intent"/*/"$sid.md"
	# A full glossary and record, and the other records that aren't done, still
	# fit under the cap with long paths.
	for d in "$long/state/knackpack/intent"/*/; do
		awk 'BEGIN { for (i = 0; i < 200; i++) print "- term" i ": a meaning long enough to fill the glossary" }' >"${d}glossary.md"
		# Older than the record below, which stays current, but not old enough
		# for the session-start cleanup.
		for i in 2 3 4 5; do
			printf '%s\n' "# Intent record: a side task whose title is long enough to come close to the limit on titles $i" '- Status: active' >"$d$sid.$i.md"
			touch -r "$long/project" "$d$sid.$i.md"
		done
		awk 'BEGIN { print "# Intent record: test"; for (i = 0; i < 200; i++) print "- REQ-" i ": a requirement long enough to fill the record" }' >"$d$sid.md"
	done
	run "$s" state "$event" || hook_ok=0
	state_size=$(wc -c <"$tmp/out" | tr -d ' ')
	[ "$state_size" -le 9900 ] || { fail "hook state output is $state_size bytes with ${#long}-character paths; keep it under 9,900"; hook_ok=0; }
	grep -q '^- and 1 more$' "$tmp/out" || { fail "hook state under $s doesn't list the session's other records that aren't done"; hook_ok=0; }
	rm -f "$long/state/knackpack/intent"/*/glossary.md "$long/state/knackpack/intent"/*/"$sid".*md
	# A glossary too long to print loses whole lines, never part of one, so a
	# character outside ASCII is never split.
	for d in "$long/state/knackpack/intent"/*/; do
		awk 'BEGIN { for (i = 0; i < 60; i++) printf "- Ausgabepr\303\274fung %d: die Pr\303\274fung der Ausgabe f\303\274r gro\303\237e \303\204nderungen\n", i }' >"${d}glossary.md"
		run "$s" state "$event" || hook_ok=0
		LC_ALL=C sed -n '/^## Personal glossary/,/^----- end -----$/p' "$tmp/out" | LC_ALL=C sed '1,/^----- begin -----$/d; /^----- end -----$/d; /^$/d' >"$tmp/gloss"
		bad=$(LC_ALL=C grep -vxF -f "${d}glossary.md" "$tmp/gloss" | LC_ALL=C grep -v '^\[Shortened from [0-9]* bytes; left out: everything from line [0-9]* on\. Read the file for the rest\.\]$')
		{ [ -s "$tmp/gloss" ] && [ -z "$bad" ] && grep -q '^\[Shortened from' "$tmp/gloss"; } ||
			{ fail "hook state under $s cuts a long glossary inside a line: $(printf '%s' "$bad" | head -c 100)"; hook_ok=0; }
		rm -f "${d}glossary.md"
	done
	# A record too long to print keeps its open questions and Built, and drops
	# rejected proposals and the oldest History first, saying so.
	for d in "$long/state/knackpack/intent"/*/; do
		awk 'BEGIN {
			print "# Intent record: test"; print "## Agreed"
			for (i = 0; i < 60; i++) print "- REQ-" i ": a requirement long enough to fill the record"
			print "## Not agreed"; print "- PROP-01: Drop it, by Claude. rejected"
			print "## Open questions"; print "- Q-01: still open"; print "## Built"; print "- REQ-1: verified"
			print "## History"; for (i = 0; i < 150; i++) print "- 2026-10-30: history entry " i
		}' >"$d$sid.md"
	done
	run "$s" state "$event" || hook_ok=0
	{ grep -q '^- Q-01: still open$' "$tmp/out" && grep -q '^- 2026-10-30: history entry 149$' "$tmp/out" &&
		! grep -q 'PROP-01' "$tmp/out" && grep -q '^\[Shortened from .*left out: rejected proposals, older History entries' "$tmp/out"; } ||
		{ fail "hook state under $s didn't shorten a long record by dropping rejected proposals and old History first"; hook_ok=0; }
	# It keeps or drops a History entry whole, with the line under it. Two
	# record sizes, since the room left decides where a cut would fall.
	for n in 40 41; do
		for d in "$long/state/knackpack/intent"/*/; do
			awk -v n="$n" 'BEGIN {
				print "# Intent record: test"; print "## Agreed"
				for (i = 0; i < n; i++) print "- REQ-" i ": a requirement long enough to fill the record"
				print "## History"
				for (i = 0; i < 80; i++) { print "- 2026-10-30: history entry " i ", whose first line is far longer than the line under it"; print "  - detail " i }
			}' >"$d$sid.md"
		done
		run "$s" state "$event" || hook_ok=0
		sed -n '/^## History/{n;p;}' "$tmp/out" | grep -q '^- 2026' ||
			{ fail "hook state under $s starts a shortened History inside an entry: $(sed -n '/^## History/{n;p;}' "$tmp/out")"; hook_ok=0; }
	done
	# A Status line of 6,000 bytes is cut at a space before byte 400, saying
	# so, and leaves room for every Agreed entry.
	for d in "$long/state/knackpack/intent"/*/; do
		awk 'BEGIN {
			print "# Intent record: test"; print ""
			s = "- Status: active, plus how to work:"; while (length(s) < 6000) s = s " keep the change small"; print s
			print "## Agreed"; for (i = 1; i <= 40; i++) print "- REQ-" i ": a requirement long enough to fill the record"
		}' >"$d$sid.md"
	done
	run "$s" state "$event" || hook_ok=0
	st=$(grep '^- Status:' "$tmp/out")
	cut=${st%" [...]"}
	{ [ "$cut" != "$st" ] && [ "${#cut}" -le 400 ] && case $(grep '^- Status:' "$d$sid.md") in "$cut "*) ;; *) false ;; esac &&
		grep -q '^- REQ-40: ' "$tmp/out" && grep -q '^\[Shortened from [0-9]* bytes; left out: the end of the Status line\. ' "$tmp/out"; } ||
		{ fail "hook state under $s doesn't cut a long Status line at a space to keep the Agreed entries: $(printf '%s' "$st" | tail -c 60)"; hook_ok=0; }
	# So is any other line past 1,000 bytes, such as a Goal written as one
	# paragraph, which would otherwise hide every section after it.
	for d in "$long/state/knackpack/intent"/*/; do
		awk 'BEGIN {
			print "# Intent record: test"; print ""; print "## Goal"
			s = "Ship the export"; while (length(s) < 7000) s = s " and keep it small"; print s
			print "## Agreed"; print "- REQ-1: a requirement"; print "## Open questions"; print "- Q-01: still open"
		}' >"$d$sid.md"
	done
	run "$s" state "$event" || hook_ok=0
	g=$(grep '^Ship the export' "$tmp/out")
	{ [ "${#g}" -le 1006 ] && case $g in *' [...]') ;; *) false ;; esac && grep -q '^- Q-01: still open$' "$tmp/out" &&
		grep -q '^\[Shortened from [0-9]* bytes; left out: the ends of long lines\. ' "$tmp/out"; } ||
		{ fail "hook state under $s doesn't cut a long line at a space to keep the sections after it: $(printf '%s' "$g" | tail -c 60)"; hook_ok=0; }
	# It names the files on the record's Files line that are gone, at most
	# three, whether or not a path is in backticks or holds a space.
	for d in "$long/state/knackpack/intent"/*/; do
		printf '%s\n' '# Intent record: test' "- Files: $long/project, \`$real/gone 1.md\`, $real/gone2.md, $real/gone3.md, $real/gone4.md" >"$d$sid.md"
	done
	run "$s" state "$event" || hook_ok=0
	grep -qxF "The record's Files line names files that no longer exist: \`$real/gone 1.md\`, \`$real/gone2.md\`, \`$real/gone3.md\` and 1 more." "$tmp/out" ||
		{ fail "hook state under $s doesn't name the record's missing files: $(grep 'no longer exist' "$tmp/out")"; hook_ok=0; }
	rm -f "$long/state/knackpack/intent"/*/"$sid.md"
	# After a compaction, and only then, it points to the session's checkpoint,
	# by the same path whether TMPDIR ends in a slash, as macOS's does, or not.
	ckpt=$real/tmpdir/$fallback$sid/CHECKPOINT.md
	mkdir -p "${ckpt%/*}" && : >"$ckpt"
	for src in compact startup; do
		for t in "$real/tmpdir" "$real/tmpdir/"; do
			printf '%s' "$event" | sed "s/\"startup\"/\"$src\"/" | env -u KNACKPACK_INTENT -u CLAUDE_CODE_ENTRYPOINT CLAUDE_CODE_SESSION_ATTENDED=1 \
				TMPDIR="$t" XDG_STATE_HOME="$long/state" CLAUDE_PROJECT_DIR="$long/project" "$s" "$hook" state >"$tmp/out" 2>/dev/null
			if [ "$src" = compact ]; then
				grep -qF "This session has a checkpoint: \`$ckpt\`." "$tmp/out" ||
					{ fail "hook state under $s on compact with TMPDIR=$t doesn't point to $ckpt: $(grep -o 'checkpoint: `[^`]*`' "$tmp/out")"; hook_ok=0; }
			elif grep -q '^## Checkpoint' "$tmp/out"; then
				fail "hook state under $s on startup points to the checkpoint"
				hook_ok=0
			fi
		done
	done
	rm -rf "$real/tmpdir"
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
	for m in prompt tool stop; do run "$s" "$m" "$event" || hook_ok=0; done
	for m in prompt tool stop; do
		rm -f "$turns/$sid"
		ln "$tmp/sentinel" "$turns/$sid"
		run "$s" "$m" "$event" || hook_ok=0
	done
	rm -rf "$turns"
	ln -s "$tmp/elsewhere" "$turns"
	for m in prompt tool stop; do run "$s" "$m" "$event" || hook_ok=0; done
	rm -f "$turns"
	if [ "$(cat "$tmp/sentinel")" != KEEP ] || [ -n "$(ls -A "$tmp/elsewhere")" ]; then
		fail "hook under $s writes through a link"
		hook_ok=0
	fi
	rm -rf "$tmp/elsewhere"
	# A stopped session gets the short note instead of the rules, however the
	# Status word is capitalized, and after a compaction or on resuming it
	# loads neither its record nor the glossary.
	for st in stopped Stopped; do
		for d in "$long/state/knackpack/intent"/*/; do
			printf '# Intent record: test\n\n- Status: %s · Updated: 2026-01-01\n' "$st" >"$d$sid.md"
			printf '%s\n' '- term: a meaning' >"${d}glossary.md"
		done
		run "$s" rules "$event" || hook_ok=0
		grep -q 'tracking is stopped for this session' "$tmp/out" || { fail "hook rules under $s ignores a record whose Status is $st"; hook_ok=0; }
		for src in compact resume; do
			run "$s" state "$(printf '%s' "$event" | sed "s/\"startup\"/\"$src\"/")" || hook_ok=0
			[ -s "$tmp/out" ] && { fail "hook state under $s on $src loads a session whose Status is $st: $(head -c 100 "$tmp/out" | tr '\n' ' ')"; hook_ok=0; }
		done
	done
	rm -f "$long/state/knackpack/intent"/*/glossary.md
	# A project folder whose name holds shell syntax never gets into a command
	# the hook tells Claude to run, tracked or stopped, and the rules fill in
	# every placeholder. Its own state folder holds no other record of the
	# session, which the hook would otherwise find.
	evil=$real/'evil"$(touch PWNED)"`touch PWNED`'
	mkdir -p "$evil"
	erec=$(env XDG_STATE_HOME="$tmp/evil-state" "$s" "$hook" manual "$sid" "$evil" 2>/dev/null | sed -n 's/^- Current record: `\(.*\)` .*/\1/p')
	for st in active stopped; do
		[ "$st" = active ] || printf '# Intent record: test\n\n- Status: stopped\n' >"$erec"
		printf '%s' "$event" | env -u KNACKPACK_INTENT -u CLAUDE_CODE_ENTRYPOINT CLAUDE_CODE_SESSION_ATTENDED=1 \
			XDG_STATE_HOME="$tmp/evil-state" CLAUDE_PROJECT_DIR="$evil" "$s" "$hook" rules >"$tmp/out" 2>/dev/null
		{ grep -q " manual $sid" "$tmp/out" && ! grep 'manual' "$tmp/out" | grep -qF 'PWNED'; } ||
			{ fail "hook rules under $s, $st, puts the project's folder into the command it tells Claude to run: $(grep -o '`sh [^`]*manual[^`]*' "$tmp/out")"; hook_ok=0; }
		[ "$st" = stopped ] || { ! grep -q 'too long to print here' "$tmp/out" && ! grep -qF '${CLAUDE_' "$tmp/out"; } ||
			{ fail "hook rules under $s, for that folder, aren't the rules with every placeholder filled: $(grep -oE 'too long to print here|[$][{]CLAUDE_[A-Z_]*[}]' "$tmp/out" | head -n 1)"; hook_ok=0; }
	done
	rm -rf "$evil" "$tmp/evil-state"
done
[ "$hook_ok" = 1 ] && pass "hook under$shells (with a ${#plug}-character plugin root and ${#long}-character paths: rules $size bytes, state $state_size)"
export HOME="$real_home"
if [ -n "$nosystem" ]; then export GIT_CONFIG_NOSYSTEM="$nosystem"; else unset GIT_CONFIG_NOSYSTEM; fi

# Outside evals/, whose fixtures may hold either on purpose, no merge-conflict
# markers and no CRLF line endings, which break a script under sh. Anywhere,
# no two names that differ only in case, which macOS and Windows can't check
# out side by side, and no file over 512 KiB, which every install downloads.
files_ok=1
bad=$(git grep --untracked -lE '^(<{7}|\|{7}|>{7})( |$)' -- . ':(exclude)evals' | tr '\n' ' ')
[ -z "$bad" ] || { fail "merge-conflict markers in: $bad"; files_ok=0; }
# The name follows a tab in --eol's output, and the size the first spaces in
# wc's, so a name with spaces in it comes out whole.
bad=$(git -c core.quotePath=false ls-files --eol -- . ':(exclude)evals' | awk -F '\t' '$1 ~ /^i\/(crlf|mixed) / { print $2 }' | tr '\n' ' ')
[ -z "$bad" ] || { fail "CRLF line endings in: $bad"; files_ok=0; }
bad=$(git -c core.quotePath=false ls-files | tr '[:upper:]' '[:lower:]' | sort | uniq -d | tr '\n' ' ')
[ -z "$bad" ] || { fail "file names that differ only in case: $bad"; files_ok=0; }
bad=$(git ls-files -z --cached --others --exclude-standard | xargs -0 wc -c 2>/dev/null |
	awk '{ size = $1; sub(/^ *[0-9]+ /, "") } $0 != "total" && size > 524288' | tr '\n' ' ')
[ -z "$bad" ] || { fail "files over 512 KiB: $bad"; files_ok=0; }
[ "$files_ok" = 1 ] && pass "no conflict markers, CRLF line endings, names differing only in case or files over 512 KiB"

# The merge gate binds everyone, admins included. The file sets the empty
# list outright, so applying it with PUT also removes a bypass added on GitHub.
if jq -e '.bypass_actors == []' .github/rulesets/main.json >/dev/null 2>&1; then
	pass "the ruleset lists no bypass actors"
else
	fail ".github/rulesets/main.json needs \"bypass_actors\": [], so the ruleset binds everyone, admins included"
fi

# Claude's review of pull requests only reviews, as .claude/CLAUDE.md says:
# its token can't push or merge, it has no tool that edits files, it may run
# only its three commands and Claude Code's read-only ones, and nothing sets it
# up to commit. Comment lines are left out, as the action leaves them out of
# claude_args.
wf=.github/workflows/claude-code-review.yml
review_ok=1
review_fail() {
	fail "$wf: $1"
	review_ok=0
}
grep -v '^[[:space:]]*#' "$wf" >"$tmp/wf"
# The review job, from its key to the next job's.
awk '/^[^[:space:]]/ { injobs = ($0 ~ /^jobs:/); job = ""; next }
	injobs && /^  [^[:space:]]/ { job = $0; sub(/^  /, "", job); sub(/:.*/, "", job); next }
	injobs && job == "review"' "$tmp/wf" >"$tmp/review"
[ -s "$tmp/review" ] || review_fail "has no review job"
# Its permissions, one per line under the job's permissions key.
perms=$(awk '
	function indent(s) { match(s, /^ */); return RLENGTH }
	/^    permissions:/ { on = 1; v = $0; sub(/^    permissions:[[:space:]]*/, "", v); sub(/[[:space:]]*#.*/, "", v); if (v != "") print v; next }
	on && NF && indent($0) <= 4 { on = 0 }
	on && NF { v = $0; sub(/[[:space:]]+#.*/, "", v); gsub(/[[:space:]]/, "", v); print v }' "$tmp/review" | LC_ALL=C sort | tr '\n' ' ')
[ "$perms" = 'contents:read pull-requests:write ' ] ||
	review_fail "the review job's permissions must be exactly contents: read and pull-requests: write, one per line, not: ${perms:-none}"
grep -Eq '^[[:space:]]+github_token:[[:space:]]*[$][{][{][[:space:]]*github[.]token[[:space:]]*[}][}][[:space:]]*(#.*)?$' "$tmp/review" ||
	review_fail "the review must pass github_token: \${{ github.token }}, or the action may use the Claude app's token, which can push"
# The tool rules, each a double-quoted, comma-separated list after its flag.
tool_list() { # <flag, as a sed pattern>
	sed -n "s/.*--$1[[:space:]=]*\"\([^\"]*\)\".*/\1/p" "$tmp/review" | tr ',' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; /^$/d'
}
denied=$(tool_list 'disallowed-\{0,1\}[Tt]ools')
missing=
for t in Edit Write MultiEdit NotebookEdit; do
	printf '%s\n' "$denied" | grep -qx "$t" || missing="$missing $t"
done
[ -z "$missing" ] || review_fail "--disallowedTools, as one double-quoted list, doesn't name:$missing"
grep -e '--allowed-\{0,1\}[Tt]ools' "$tmp/review" | grep -qv -e '--allowed-\{0,1\}[Tt]ools[[:space:]=]*"' &&
	review_fail "write --allowedTools as one double-quoted, comma-separated list, which this check can read"
pr='${{ github.event.pull_request.number }}'
extra=$(tool_list 'allowed-\{0,1\}[Tt]ools' | grep -vxF -e "Bash(gh pr diff $pr)" -e "Bash(gh pr diff $pr --name-only)" -e "Bash(gh pr view $pr)" \
	-e mcp__github_inline_comment__create_inline_comment | tr '\n' ' ')
[ -z "$extra" ] || review_fail "--allowedTools approves more than the three gh pr commands and the inline-comment tool: $extra"
# Anywhere in the workflow: the inputs and tools that let Claude commit, push
# or merge, and the permission modes that would run commands nobody approved.
bad=$(grep -oE -e 'use_commit_signing|ssh_signing_key|mcp__github_file_ops|mcp__github(__|[^_[:alnum:]]|$)' \
	-e 'dangerously-skip-permissions|--permission-mode|bypassPermissions' "$tmp/wf" | sed 's/[^_[:alnum:]-]$//' | LC_ALL=C sort -u | tr '\n' ' ')
[ -z "$bad" ] || review_fail "gives Claude a way to commit, push or merge, or to run commands nobody approved: $bad"
[ "$review_ok" = 1 ] && pass "Claude's pull request review can't edit files or push: its token, tool rules and permission mode"

# Linters, each run when it's installed, on the files git tracks or would add
# outside evals/, whose fixtures hold the defects their cases are about, and
# outside npm's lockfile. CI's Linux job installs the versions pinned in
# .github/linters and sets KNACKPACK_LINTERS=required, so a missing one fails
# there; KNACKPACK_LINTERS=off skips them all, as CI's macOS job does.
# ShellCheck reads every script as POSIX sh and reports warnings and errors;
# its notes here are idioms the scripts use on purpose. lychee fails a link
# whose host can't be reached or that answers 4xx other than 429. A rate
# limit, server error or timeout passes, since a later run would, and a
# required check mustn't fail at random. With GITHUB_TOKEN set, zizmor runs
# its online audits too and lychee gets GitHub's higher rate limit. gitleaks
# prints what it finds redacted.
git -c core.quotePath=false ls-files --cached --others --exclude-standard -- . ':(exclude)evals' ':(exclude,glob)**/package-lock.json' |
	while IFS= read -r f; do [ -f "$f" ] && printf '%s\n' "$f"; done >"$tmp/files"
each() { tr '\n' '\0' | xargs -0 "$@"; } # <command>...: runs it on the names on stdin, one per line
skipped=
lint() { # <tool>
	if [ "${KNACKPACK_LINTERS-}" = off ] || ! command -v "$1" >/dev/null 2>&1; then
		if [ "${KNACKPACK_LINTERS-}" = required ]; then fail "$1 isn't installed"; else skipped="$skipped $1"; fi
		return
	fi
	case $1 in
	shellcheck) grep '\.sh$' "$tmp/files" | each shellcheck -s sh -S warning ;;
	actionlint) grep '^\.github/workflows/[^/]*\.ya\{0,1\}ml$' "$tmp/files" | each actionlint -no-color ;;
	zizmor) zizmor --persona pedantic --strict-collection --no-progress --color never .github ;;
	codespell) each codespell <"$tmp/files" ;;
	markdownlint-cli2) grep '\.md$' "$tmp/files" | sed 's/^/:/' | each markdownlint-cli2 --config .github/linters/markdownlint-cli2.jsonc ;;
	lychee) each lychee --no-progress --include-verbatim --include-fragments --exclude-loopback --max-retries 3 --retry-wait-time 2 --timeout 20 \
		--accept '100..=103,200..=299,429,500..=599' --accept-timeouts <"$tmp/files" ;;
	gitleaks) mkdir "$tmp/scan" && tar -cf - -T "$tmp/files" | tar -xf - -C "$tmp/scan" &&
		(cd "$tmp/scan" && gitleaks dir --no-banner --no-color --redact --verbose --log-level warn .) ;;
	esac >"$tmp/lint" 2>&1
	if [ $? = 0 ]; then pass "$1"; else fail "$1:"; cat "$tmp/lint"; fi
}
for l in shellcheck actionlint zizmor codespell markdownlint-cli2 lychee gitleaks; do lint "$l"; done
if [ -n "$skipped" ]; then
	if [ "${KNACKPACK_LINTERS-}" = off ]; then why='KNACKPACK_LINTERS=off'; else why='not installed'; fi
	printf 'skip  %s:%s\n' "$why" "$skipped"
fi

# A changed plugin needs a new version, or installed copies never update, and
# a version below origin/main's means a merge or rebase went wrong. Files under
# .github/ change nothing the plugin does, so a change to them alone, such as
# Dependabot's, needs no new version.
higher() { # <a> <b>: a is a higher x.y.z than b
	printf '%s\n%s\n' "$1" "$2" | awk -F. '
		NR == 1 { for (i = 1; i <= 3; i++) a[i] = $i + 0; next }
		{ for (i = 1; i <= 3; i++) { if (a[i] > $i + 0) exit 0; if (a[i] < $i + 0) exit 1 }; exit 1 }'
}
cur=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' .claude-plugin/plugin.json)
pub=$(git show origin/main:.claude-plugin/plugin.json 2>/dev/null | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
if [ -z "$pub" ]; then
	fail "can't read the version on origin/main"
elif [ "$cur" = "$pub" ] && { ! git diff --quiet origin/main -- . ':(exclude).github' || [ -n "$(git ls-files --others --exclude-standard -- . ':(exclude).github')" ]; }; then
	fail "the plugin changed since origin/main but its version is still $cur"
elif [ "$cur" != "$pub" ] && ! higher "$cur" "$pub"; then
	fail "version $cur is lower than origin/main's $pub"
else
	pass "version $cur (origin/main has $pub)"
fi

exit "$failed"
