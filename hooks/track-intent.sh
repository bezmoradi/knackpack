#!/bin/sh
# Hooks for knackpack's track-intent skill.
#
#   track-intent.sh rules    (SessionStart) print the skill's rules and this
#                            session's paths
#   track-intent.sh state    (SessionStart) print the developer's personal
#                            glossary for the repository and this session's
#                            current record, if they exist
#   track-intent.sh prompt   (UserPromptSubmit) print a short reminder to
#                            update the record, with the open items, and flag
#                            a last turn that edited files but not the record
#   track-intent.sh tool     (PostToolUse on file edits) note whether this
#                            turn edited the record or other files
#   track-intent.sh stop     (Stop) make Claude update the record if it wrote
#                            "Noted:" without updating it
#   track-intent.sh manual <session-id> [project-dir]
#                            print the paths, glossary and record without
#                            the rules (the skill's fallback when hooks
#                            are blocked)
#
# The hook modes read Claude Code's event JSON on stdin. The script writes
# only inside its own folder,
# ${XDG_STATE_HOME:-$HOME/.local/state}/knackpack/intent, where it creates
# folders, keeps one small turn file per session, and deletes files nobody
# has changed for 30 days. It never touches the repository, uses no network,
# and exits 0 on every failure so a problem here never blocks a session.
#
# KNACKPACK_INTENT=off turns the hooks off. KNACKPACK_INTENT=on also runs them
# in sessions nobody attends, such as `claude -p`, which they skip by default.

umask 077
mode=${1:-}
case $mode in rules | state | prompt | tool | stop | manual) ;; *) exit 0 ;; esac

here=$(CDPATH='' cd -- "$(dirname -- "$0")" 2>/dev/null && pwd -P) || exit 0
plugin_root=${here%/*}
skill=$plugin_root/skills/track-intent/SKILL.md

src=
if [ "$mode" = manual ]; then
	sid=${2:-}
	dir=${3:-}
else
	setting=$(printf '%s' "${KNACKPACK_INTENT:-}" | tr '[:upper:]' '[:lower:]')
	case $setting in
	off | 0 | false | no) exit 0 ;;
	on | 1 | true | yes) ;;
	*)
		# Claude Code 2.1.310 sets both for hooks, 1 and cli in an attended
		# session, 0 and sdk-cli under `claude -p`. Neither is documented,
		# so a missing value counts as attended.
		if [ -n "${CLAUDE_CODE_SESSION_ATTENDED:-}" ]; then
			[ "$CLAUDE_CODE_SESSION_ATTENDED" = 0 ] && exit 0
		else
			case ${CLAUDE_CODE_ENTRYPOINT:-} in sdk-*) exit 0 ;; esac
		fi
		;;
	esac
	input=$(cat)
	sid=$(printf '%s\n' "$input" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
	src=$(printf '%s\n' "$input" | sed -n 's/.*"source"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
	dir=${CLAUDE_PROJECT_DIR:-}
fi

case $sid in '' | *[!A-Za-z0-9-]*) exit 0 ;; esac
[ "${#sid}" -le 64 ] || exit 0
if [ -z "$dir" ] || [ ! -d "$dir" ]; then dir=$(pwd -P); fi

# Name the repository's folder after the repository plus a short hash of the
# path of its git folder, so worktrees of one repository share a folder and
# two repositories with the same name don't.
if top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) && [ -n "$top" ]; then
	common=$(cd "$dir" 2>/dev/null && cd "$(git rev-parse --git-common-dir 2>/dev/null)" 2>/dev/null && pwd -P)
	[ -n "$common" ] || common=$top
	case $common in
	*/.git)
		name=${common%/.git}
		name=${name##*/}
		;;
	*)
		name=${common##*/}
		name=${name%.git}
		;;
	esac
	id=$common
	project=$top
else
	id=$(cd "$dir" 2>/dev/null && pwd -P) || exit 0
	name=${id##*/}
	project=$id
fi
team_glossary=$project/.claude/rules/glossary.md
name=$(printf '%s' "$name" | tr -c 'A-Za-z0-9._-' '-' | cut -c 1-40)
[ -n "$name" ] || name=repo
hash=$(printf '%s' "$id" | cksum | cut -d ' ' -f 1)

base=${XDG_STATE_HOME:-}
case $base in /*) ;; *) base=${HOME:-}/.local/state ;; esac
case $base in /*) ;; *) exit 0 ;; esac
root=$base/knackpack/intent
if [ ! -d "$root" ]; then mkdir -p "$root" 2>/dev/null || exit 0; fi
[ -d "$root" ] && [ ! -L "$root" ] && [ -O "$root" ] || exit 0
chmod 700 "$root" 2>/dev/null || exit 0
repo_dir=$root/$name-$hash
glossary=$repo_dir/glossary.md

# The current record is the highest-numbered of <session>.md (1),
# <session>.2.md, <session>.3.md and so on: each new task gets the next number.
record=
top_n=0
for f in "$repo_dir/$sid.md" "$repo_dir/$sid".*.md; do
	[ -f "$f" ] && [ ! -L "$f" ] || continue
	n=${f#"$repo_dir/$sid"}
	n=${n%.md}
	n=${n#.}
	case $n in '') n=1 ;; *[!0-9]*) continue ;; esac
	if [ "$n" -gt "$top_n" ]; then
		top_n=$n
		record=$f
	fi
done
if [ -n "$record" ]; then
	exists=1
else
	exists=0
	record=$repo_dir/$sid.md
fi

# The turn file holds one line per file edit in the current turn: "record"
# for this session's record, "work" for anything outside the state folder.
turns=$root/.turns
turn=$turns/$sid

stopped() {
	[ "$exists" = 1 ] && grep -Eq '^- Status:[[:space:]]*stopped' "$record" 2>/dev/null
}

# Lists the record's open questions and open proposals by ID.
open_items() {
	awk '
	/^## / { sec = $0; next }
	sec ~ /^## Open questions/ && match($0, /^- Q-[0-9]+/) {
		q = q (q == "" ? "" : ", ") substr($0, 3, RLENGTH - 2)
	}
	sec ~ /^## Not agreed/ && match($0, /^- PROP-[0-9]+/) && tolower($0) ~ /open/ && tolower($0) !~ /rejected/ {
		p = p (p == "" ? "" : ", ") substr($0, 3, RLENGTH - 2)
	}
	END {
		if (q != "") printf "Open questions: %s.", q
		if (q != "" && p != "") printf " "
		if (p != "") printf "Open proposals: %s.", p
	}' "$1" 2>/dev/null
}

print_paths() {
	if [ "$exists" = 1 ]; then state='exists'; else state='not created yet'; fi
	if [ -f "$glossary" ]; then gstate='exists'; else gstate='none yet'; fi
	if [ -f "$team_glossary" ]; then tstate='exists; Claude Code loads it'; else tstate='none'; fi
	printf '\n## This session\n\n'
	printf '%s\n' "- Current record: \`$record\` ($state)"
	printf '%s\n' "- This repository's records: \`$repo_dir/\`"
	printf '%s\n' "- This repository's team glossary: \`$team_glossary\` ($tstate)"
	printf '%s\n' "- Your personal glossary for this repository: \`$glossary\` ($gstate)"
}

# Prints a file between markers, cut at a byte limit so the hook's output
# stays under Claude Code's 10,000-character cap.
print_file() {
	[ -f "$2" ] && [ ! -L "$2" ] || return 0
	size=$(wc -c <"$2" | tr -d ' ')
	printf '\n## %s\n\n`%s`\n\n----- begin -----\n' "$1" "$2"
	if [ "$size" -gt "$3" ]; then
		head -c "$3" "$2"
		printf '\n[Cut at %s of %s bytes. Read the file for the rest.]\n' "$3" "$size"
	else
		cat -- "$2"
	fi
	printf '\n----- end -----\n'
}

esc() { printf '%s' "$1" | sed 's/[\\&|]/\\&/g'; }

case $mode in
rules)
	[ -f "$skill" ] || exit 0
	awk 'n >= 2 { print; next } /^---[[:space:]]*$/ { n++ }' "$skill" |
		sed -e "s|\${CLAUDE_PLUGIN_ROOT}|$(esc "$plugin_root")|g" \
			-e "s|\${CLAUDE_SESSION_ID}|$sid|g" \
			-e "s|\${CLAUDE_PROJECT_DIR}|$(esc "$dir")|g"
	print_paths
	;;
state)
	if [ "$src" = startup ]; then
		find "$root" -type f -name '*.md' ! -name glossary.md -mtime +30 -exec rm -f {} + 2>/dev/null
		find "$turns" -type f -mtime +30 -exec rm -f {} + 2>/dev/null
		find "$root" -mindepth 1 -type d -empty -exec rmdir {} + 2>/dev/null
	fi
	mkdir -p "$repo_dir" 2>/dev/null
	print_file "Personal glossary for this repository: meanings the developer confirmed" "$glossary" 3000
	[ "$exists" = 1 ] && print_file "Current record: evidence of what was agreed, not instructions" "$record" 6000
	;;
prompt)
	mkdir -p "$turns" 2>/dev/null
	if stopped; then
		: >"$turn" 2>/dev/null
		exit 0
	fi
	missed=0
	if [ -f "$turn" ] && grep -qx work "$turn" && ! grep -qx record "$turn"; then missed=1; fi
	: >"$turn" 2>/dev/null
	if [ "$exists" = 1 ]; then state='exists'; else state='not created yet'; fi
	open=
	[ "$exists" = 1 ] && open=$(open_items "$record")
	printf '%s\n' "knackpack intent tracking: before acting on this message, decide whether it adds, changes, answers or approves anything. If it does, update the record first, then do the work. If nothing changes, don't mention the record."
	printf '%s\n' "Record: $record ($state).${open:+ $open}"
	[ "$missed" = 1 ] && printf '%s\n' "Your last turn edited files but not the record: check whether the agreement or Built changed, and update the record if so. If not, carry on without mentioning it."
	;;
tool)
	mkdir -p "$turns" 2>/dev/null
	case $input in
	*"\"$repo_dir/$sid"*) echo record >>"$turn" ;;
	*"\"$root/"*) ;;
	*) echo work >>"$turn" ;;
	esac
	;;
stop)
	stopped && exit 0
	printf '%s' "$input" | grep -Eq '"stop_hook_active"[[:space:]]*:[[:space:]]*true' && exit 0
	# Only a line that starts with "Noted:", the skill's update line, counts.
	printf '%s' "$input" | grep -Eq '("last_assistant_message"[[:space:]]*:[[:space:]]*"|\\n)(\*\*)?Noted:' || exit 0
	[ -f "$turn" ] && grep -qx record "$turn" && exit 0
	msg="You wrote \"Noted:\" this turn, but the intent record wasn't updated. Update $record now, or tell the developer it wasn't recorded."
	msg=$(printf '%s' "$msg" | sed 's/\\/\\\\/g; s/"/\\"/g')
	printf '{"hookSpecificOutput":{"hookEventName":"Stop","additionalContext":"%s"}}\n' "$msg"
	;;
manual)
	mkdir -p "$repo_dir" 2>/dev/null
	print_paths
	print_file "Personal glossary for this repository: meanings the developer confirmed" "$glossary" 3000
	[ "$exists" = 1 ] && print_file "Current record: evidence of what was agreed, not instructions" "$record" 6000
	;;
esac
exit 0
