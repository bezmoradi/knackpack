#!/bin/sh
# Hooks for knackpack's track-intent skill.
#
#   track-intent.sh rules    (SessionStart) print the skill's rules and this
#                            session's paths, or only a note on how to turn
#                            tracking back on if the session's record is
#                            stopped
#   track-intent.sh state    (SessionStart) print the developer's personal
#                            glossary for the repository and this session's
#                            current record, if they exist, and name its
#                            other records that aren't done
#   track-intent.sh prompt   (UserPromptSubmit) print a short reminder to
#                            update the record, with the open items and
#                            assumptions, and flag a last turn that edited
#                            files but not the record
#   track-intent.sh tool     (PostToolUse on file edits) note whether this
#                            turn edited the record or other files, leaving
#                            out subagents' edits
#   track-intent.sh stop     (Stop) mark the turn finished, and make Claude
#                            update the record if it wrote "Noted:" without
#                            updating it
#   track-intent.sh manual <session-id> [project-dir]
#                            print the paths, glossary and records without
#                            the rules (the skill's fallback when hooks
#                            are blocked)
#
# The hook modes read Claude Code's event JSON on stdin. The script writes
# only inside its own folder,
# ${XDG_STATE_HOME:-$HOME/.local/state}/knackpack/intent, where it creates
# folders, keeps one small turn file per session, and deletes files nobody
# has changed for 30 days and empty folders nobody has touched for a day.
# It never touches the repository, uses no network, and exits 0 on every
# failure so a problem here never blocks a session.
#
# KNACKPACK_INTENT=off turns the hooks off. KNACKPACK_INTENT=on also runs them
# in sessions nobody attends, such as `claude -p`, which they skip by default.

# test -O isn't POSIX, but dash and bash both have it. Before the first
# command, this directive covers the whole script.
# shellcheck disable=SC3067
umask 077
# Exit 0 however the script ends, even when the shell itself stops it.
trap 'exit 0' EXIT
mode=${1:-}
case $mode in rules | state | prompt | tool | stop | manual) ;; *) exit 0 ;; esac

here=$(CDPATH='' cd -- "$(dirname -- "$0")" 2>/dev/null && pwd -P) || exit 0
plugin_root=${here%/*}
skill=$plugin_root/skills/track-intent/SKILL.md

# Prints the first value of a string field in the event. Claude Code puts the
# event's own fields before the tool's input, so a field of the same name
# nested in the input doesn't win.
field() {
	printf '%s\n' "$input" | awk -v k="$1" '
	match($0, "\"" k "\"[ \t]*:[ \t]*\"[^\"]*\"") {
		s = substr($0, RSTART, RLENGTH)
		sub(/^"[^"]*"[ \t]*:[ \t]*"/, "", s)
		print substr(s, 1, length(s) - 1)
		exit
	}'
}

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
	sid=$(field session_id)
	src=$(field source)
	dir=${CLAUDE_PROJECT_DIR:-}
fi

case $sid in '' | *[!A-Za-z0-9-]*) exit 0 ;; esac
[ "${#sid}" -le 64 ] || exit 0
if [ -z "$dir" ] || [ ! -d "$dir" ]; then dir=$(pwd -P); fi

# Name the repository's folder after the repository plus a short hash of the
# path of its git folder, so worktrees of one repository share a folder and
# two repositories with the same name don't. A repository at the home folder,
# such as one for dotfiles, doesn't count: every folder under it would share
# its records, and its .claude/rules/ loads in every project.
home=$(CDPATH='' cd -- "${HOME:-/nonexistent}" 2>/dev/null && pwd -P)
if top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) && [ -n "$top" ] && [ "$top" != "$home" ]; then
	common=$(CDPATH='' cd -- "$dir" 2>/dev/null && CDPATH='' cd -- "$(git rev-parse --git-common-dir 2>/dev/null)" 2>/dev/null && pwd -P)
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
	id=$(CDPATH='' cd -- "$dir" 2>/dev/null && pwd -P) || exit 0
	name=${id##*/}
	project=$id
fi
team_glossary=$project/.claude/rules/glossary.md
[ "$project" != "$home" ] || team_glossary=
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
# Claude Code normalizes a tool's file path before a hook sees it, and the
# paths below are compared as text, so collapse `//`, `.`, `..` and a trailing
# slash here too, without resolving symbolic links.
root=$(CDPATH='' cd -- "$root" 2>/dev/null && pwd -L) || exit 0
# A leading `//` survives `pwd`, since POSIX leaves it to the implementation,
# but Claude Code collapses it, so cut it down to one slash.
case $root in //*) root=/${root#"${root%%[!/]*}"} ;; esac
# The normalized path can name another folder than the one checked above when
# `..` follows a symbolic link, so check it too before writing anything.
[ -d "$root" ] && [ ! -L "$root" ] && [ -O "$root" ] || exit 0
chmod 700 "$root" 2>/dev/null || exit 0
repo_dir=$root/$name-$hash
glossary=$repo_dir/glossary.md

# The session's records are <session>.md (1), <session>.2.md, <session>.3.md
# and so on: each new task gets the next number. Every loop over them goes
# through record_n, which passes a regular file with such a name, not a link,
# and sets n to its number, so a file such as <session>.notes.md is never one.
record_n() {
	[ -f "$1" ] && [ ! -L "$1" ] || return 1
	case ${1#"$repo_dir/$sid"} in
	.md) n=1 ;;
	.*.md)
		n=${1#"$repo_dir/$sid."}
		n=${n%.md}
		case $n in '' | *[!0-9]* | ??????????*) return 1 ;; esac
		;;
	*) return 1 ;;
	esac
}
# The current one is the record edited last that isn't done, so a side task's
# record gives way to the main task's once either the main one is updated
# again or the side task is done; on a tie, the highest-numbered. When every
# record is done, the one edited last. A stopped record isn't passed over, so
# stopping tracking holds.
is_done() { grep -Eq '^- Status:[[:space:]]*[Dd]one([^A-Za-z]|$)' "$1" 2>/dev/null; }
pick() { # <1 to pass over records that are done>
	record=
	top_n=0
	for f in "$repo_dir/$sid.md" "$repo_dir/$sid".*.md; do
		record_n "$f" || continue
		[ "$1" = 1 ] && is_done "$f" && continue
		if [ "$n" -gt "$top_n" ]; then
			top_n=$n
			record=$f
		fi
	done
	for f in "$repo_dir/$sid.md" "$repo_dir/$sid".*.md; do
		[ -n "$record" ] && [ "$f" != "$record" ] && record_n "$f" || continue
		[ "$1" = 1 ] && is_done "$f" && continue
		[ -n "$(find "$f" -prune -newer "$record" 2>/dev/null)" ] && record=$f
	done
}
pick 1
[ -n "$record" ] || pick 0
if [ -n "$record" ]; then
	exists=1
else
	exists=0
	record=$repo_dir/$sid.md
fi

# The turn file starts with "sum <checksum>" of the session's records at the
# turn's first prompt, then holds one line per file edit in the turn: "record"
# for this session's record, "work" for anything outside the state folder and
# the folders where skills save files: Claude Code's scratchpad,
# <session>/scratchpad, and knackpack's fallback, claude-<session>. Stop adds
# "end", and only a prompt after it starts a new turn.
turns=$root/.turns
turn=$turns/$sid

# Writes to the turn file go only through a real folder the hook owns, never
# through a symbolic or hard link: a link or anything else at the file's path
# is removed first. Only this user can write in the folder, so no other user can swap
# one in between the check and the write.
turn_ok() {
	mkdir -p "$turns" 2>/dev/null
	[ -d "$turns" ] && [ ! -L "$turns" ] && [ -O "$turns" ] || return 1
	if [ -L "$turn" ] || { [ -e "$turn" ] && [ ! -f "$turn" ]; } ||
		[ -n "$(find "$turn" -prune -links +1 2>/dev/null)" ]; then
		rm -f "$turn" 2>/dev/null
	fi
	[ ! -L "$turn" ] && { [ ! -e "$turn" ] || [ -f "$turn" ]; }
}

# A checksum of the session's records, so an update made with any tool, a
# shell command included, shows as a change between the prompt and the end of
# the turn.
records_sum() {
	for f in "$repo_dir/$sid.md" "$repo_dir/$sid".*.md; do
		record_n "$f" && cat -- "$f"
	done 2>/dev/null | cksum 2>/dev/null
}

stopped() {
	[ "$exists" = 1 ] && grep -Eq '^- Status:[[:space:]]*[Ss]topped([^A-Za-z]|$)' "$record" 2>/dev/null
}

# Names the session's other records that aren't done, one per line with its
# Status and title, at most three, so the current record never hides a task
# that's still open.
others() { # <character to put around each path, or none>
	k=0
	for f in "$repo_dir/$sid.md" "$repo_dir/$sid".*.md; do
		[ "$f" != "$record" ] && record_n "$f" || continue
		is_done "$f" && continue
		k=$((k + 1))
		[ "$k" -le 3 ] || continue
		st=$(sed -n 's/^- Status:[[:space:]]*\([A-Za-z]*\).*/\1/p' "$f" 2>/dev/null | head -n 1)
		title=$(sed -n '1s/^# Intent record:[[:space:]]*//p' "$f" 2>/dev/null | tr -d '\000-\037')
		[ "${#title}" -le 100 ] || title=
		printf '%s%s%s (%s%s)\n' "${1:-}" "$f" "${1:-}" "${st:-no status}" "${title:+: $title}"
	done
	[ "$k" -le 3 ] || printf 'and %s more\n' "$((k - 3))"
}

# Lists the record's open questions and open proposals by ID. The layout ends
# a proposal with ", by <who>. open" or "... rejected", so its status is the
# word right after the last such attribution, or, failing that, the last one
# after a full stop, "?" or "!" that follows the last ", by ", where a closing
# quote or bracket may sit between the two. The proposal, and a note after the
# status, can contain either word. A proposal whose status still can't be
# found is named as such rather than left out.
open_items() {
	awk '
	function flush(   s, r, i, st) {
		if (id != "") {
			s = tolower(t) " "
			st = ""
			r = s
			while (match(r, /, by [^.]*\.[ \t]+(open|rejected)[^a-z]/)) {
				st = substr(r, RSTART, RLENGTH)
				r = substr(r, RSTART + RLENGTH)
			}
			if (st == "") {
				# An attribution with a full stop of its own, or none, or
				# a quote of the developer before the status.
				while ((i = index(s, ", by ")) > 0) s = substr(s, i + 5)
				while (match(s, /[.?!][")]*[ \t]+(open|rejected)[^a-z]/)) {
					st = substr(s, RSTART, RLENGTH)
					s = substr(s, RSTART + RLENGTH)
				}
			}
			if (st == "") u = u (u == "" ? "" : ", ") id
			else if (st ~ /open[^a-z]$/) p = p (p == "" ? "" : ", ") id
		}
		id = ""
	}
	{ sub(/\r$/, "") }
	/^## / { flush(); sec = $0; next }
	sec ~ /^## Open questions/ && match($0, /^- Q-[0-9]+/) {
		q = q (q == "" ? "" : ", ") substr($0, 3, RLENGTH - 2)
	}
	sec ~ /^## Not agreed/ && match($0, /^- PROP-[0-9]+/) {
		n = RLENGTH # flush() calls match(), which resets RLENGTH
		flush()
		id = substr($0, 3, n - 2)
		t = $0
		gap = 0
		next
	}
	id != "" {
		# An entry that wraps continues as in the assumptions below.
		if ($0 ~ /^[ \t]*$/) { gap = 1; next }
		if ($0 ~ /^[ \t]/ || (!gap && $0 !~ /^([-*+]|1[.)])[ \t]/ && $0 !~ /^#+([ \t]|$)/)) {
			t = t " " $0
			gap = 0
			next
		}
		flush()
	}
	END {
		flush()
		if (q != "") printf "Open questions: %s.", q
		if (q != "" && p != "") printf " "
		if (p != "") printf "Open proposals: %s.", p
		if (u != "") printf "%sProposals with no status the hook can read: %s.", (q != "" || p != "" ? " " : ""), u
	}' "$1" 2>/dev/null
}

# Lists the record's assumptions with their text, since an ID alone doesn't
# say what was assumed, one per line and as written. An entry that wraps onto
# more lines is joined, never cut at the break. Past about 1,000 characters,
# only their IDs.
assumed_items() {
	awk '
	function flush() {
		if (id == "") return
		# Cut at the last " Why:", so text that contains one is not lost.
		w = 0
		while ((i = index(substr(t, w + 1), " Why:")) > 0) w += i
		if (w > 0) t = substr(t, 1, w - 1)
		sub(/[ \t]+$/, "", t)
		if (used + length(t) <= 1000) {
			a = a "\n- " t
			used += length(t) + 3
		} else {
			more = more (more == "" ? "" : ", ") id
		}
		id = ""
	}
	{ sub(/\r$/, "") }
	/^## / { flush(); sec = $0; next }
	sec ~ /^## Assumed/ && match($0, /^- ASM-[0-9]+/) {
		flush()
		id = substr($0, 3, RLENGTH - 2)
		t = substr($0, 3)
		sub(/[ \t]+$/, "", t)
		gap = 0
		next
	}
	id != "" {
		# As in Markdown, an indented line continues the entry, and so does
		# an unindented one that follows text, unless it starts a bullet, an
		# ordered list at 1 or a heading.
		if ($0 ~ /^[ \t]*$/) { gap = 1; next }
		if ($0 ~ /^[ \t]/ || (!gap && $0 !~ /^([-*+]|1[.)])[ \t]/ && $0 !~ /^#+([ \t]|$)/)) {
			s = $0
			sub(/^[ \t]+/, "", s)
			sub(/[ \t]+$/, "", s)
			t = t " " s
			gap = 0
			next
		}
		flush()
	}
	END {
		flush()
		if (a == "" && more == "") exit
		printf "Assumed, not confirmed; check this message and your next step against them:%s", a
		if (more != "") printf "\nMore in the record: %s.", more
	}' "$1" 2>/dev/null
}

print_paths() {
	if [ "$exists" = 1 ]; then state='exists'; else state='not created yet'; fi
	if [ -f "$glossary" ]; then gstate='exists'; else gstate='none yet'; fi
	if [ -f "$team_glossary" ]; then tstate='exists; Claude Code loads it'; else tstate='none'; fi
	printf '\n## This session\n\n'
	printf '%s\n' "- Current record: \`$record\` ($state)"
	printf '%s\n' "- This repository's records: \`$repo_dir/\`"
	if [ -n "$team_glossary" ]; then
		printf '%s\n' "- This repository's team glossary: \`$team_glossary\` ($tstate)"
	else
		printf '%s\n' "- This repository's team glossary: none, since a home folder's \`.claude/rules/\` loads in every project"
	fi
	printf '%s\n' "- Your personal glossary for this repository: \`$glossary\` ($gstate)"
}

# Prints a file between markers, cut at a byte limit so the hook's output
# stays under Claude Code's 10,000-character cap.
print_file() {
	[ -f "$2" ] && [ -r "$2" ] && [ ! -L "$2" ] || return 0
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

# Prints the record like print_file, but when it's too long it drops what
# matters least first: rejected proposals and the oldest History entries, then
# whole lines from the end. It never cuts inside a line, so a multi-byte
# character can't be split, keeps or drops a History entry whole, with the
# lines under it, and says what it left out.
print_record() {
	[ -f "$2" ] && [ -r "$2" ] && [ ! -L "$2" ] || return 0
	size=$(wc -c <"$2" | tr -d ' ')
	printf '\n## %s\n\n`%s`\n\n----- begin -----\n' "$1" "$2"
	if [ "$size" -gt "$3" ]; then
		# Bytes, not characters, whatever the locale; 120 are kept for the note.
		LC_ALL=C awk -v room=$(($3 - 120)) -v size="$size" '
		{ sub(/\r$/, "") }
		/^## / { sec = $0 }
		sec ~ /^## History/ {
			# The heading and anything before the first entry, then one
			# entry per list item, each with the lines under it.
			if (/^([-*+]|[0-9]+[.)])[ \t]/) h++
			if (h) hist[h] = hist[h] $0 "\n"
			else head = head $0 "\n"
			next
		}
		sec ~ /^## Not agreed/ && tolower($0) ~ /[.?!][")]*[ \t]+rejected[^a-z]*$/ { rej++; next }
		{ body[++b] = $0; line[b] = NR }
		END {
			used = 0
			for (i = 1; i <= b; i++) {
				n = length(body[i]) + 1
				if (used + n > room) { cut = 1; break }
				printf "%s\n", body[i]
				used += n
			}
			left = rej ? "rejected proposals" : ""
			if (cut) {
				left = left (left == "" ? "" : ", ") "everything from line " line[i] " on"
			} else if (head != "") {
				# The heading, then the newest entries that fit, in order.
				keep = 0
				used += length(head)
				for (j = h; j >= 1 && used + length(hist[j]) <= room; j--) {
					used += length(hist[j])
					keep++
				}
				if (used <= room) {
					printf "%s", head
					for (j = h - keep + 1; j <= h; j++) printf "%s", hist[j]
				}
				if (keep < h) left = left (left == "" ? "" : ", ") (keep ? "older History entries" : "History")
			}
			if (left != "") printf "[Shortened from %s bytes; left out: %s. Read the file for the rest.]\n", size, left
		}' "$2"
	else
		cat -- "$2"
	fi
	printf '\n----- end -----\n'
}

esc() { printf '%s' "$1" | sed 's/[\\&|]/\\&/g'; }

case $mode in
rules)
	[ -f "$skill" ] || exit 0
	if stopped; then
		printf '%s\n' "knackpack intent tracking is stopped for this session, so its rules aren't loaded. If the developer asks to track it again, read \`$skill\` in full, after its frontmatter, set the record's Status back to active, and run \`sh \"$here/track-intent.sh\" manual $sid \"$dir\"\` for this session's paths."
		exit 0
	fi
	# After an update, a compaction can re-attach an older version's copy of
	# the skill, run earlier as a command, beside these rules, so they say
	# which version they are.
	version=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([0-9A-Za-z.+-]*\)".*/\1/p' "$plugin_root/.claude-plugin/plugin.json" 2>/dev/null | head -n 1)
	intro=
	[ -n "$version" ] && intro="These rules, from knackpack $version, replace any older copy of the track-intent skill."
	# sed can't put a line break into a replacement, so a path with one gets
	# the pointer below.
	nl='
'
	case $plugin_root$dir in
	*"$nl"*) out= ;;
	*)
		out=$(
			[ -n "$intro" ] && printf '%s\n' "$intro"
			awk 'n >= 2 { print; next } /^---[[:space:]]*$/ { n++ }' "$skill" 2>/dev/null |
				sed -e "s|\${CLAUDE_PLUGIN_ROOT}|$(esc "$plugin_root")|g" \
					-e "s|\${CLAUDE_SESSION_ID}|$sid|g" \
					-e "s|\${CLAUDE_PROJECT_DIR}|$(esc "$dir")|g" 2>/dev/null
			print_paths
		)
		;;
	esac
	# Past 10,000 characters Claude Code shows Claude only a short preview,
	# so print a pointer to the skill instead of rules that would be cut.
	# Counting bytes never undercounts characters.
	if [ -n "$out" ] && [ "$(printf '%s\n' "$out" | wc -c | tr -d ' ')" -le 9900 ]; then
		printf '%s\n' "$out"
	else
		[ -n "$intro" ] && printf '%s\n\n' "$intro"
		printf '%s\n' "# Track intent" "" "knackpack's intent-tracking rules are too long to print here with this session's paths. Read \`$skill\` in full now, after its frontmatter, and follow it for the whole session. In it, \${CLAUDE_PLUGIN_ROOT} stands for \`$plugin_root\`, \${CLAUDE_SESSION_ID} for \`$sid\` and \${CLAUDE_PROJECT_DIR} for \`$dir\`."
		print_paths
	fi
	;;
state)
	if [ "$src" = startup ]; then
		find "$root" -type f -name '*.md' ! -name glossary.md -mtime +30 -exec rm -f {} + 2>/dev/null
		[ -L "$turns" ] || find "$turns" -type f -mtime +30 -exec rm -f {} + 2>/dev/null
		# Only folders untouched for a day, so this doesn't remove the empty
		# folder another open session has just created.
		find "$root" -mindepth 1 -type d -empty -mtime +0 -exec rmdir {} + 2>/dev/null
	fi
	mkdir -p "$repo_dir" 2>/dev/null
	gloss=$(print_file "Personal glossary for this repository: meanings the developer confirmed" "$glossary" 3000)
	[ -n "$gloss" ] && printf '%s\n' "$gloss"
	# After a compaction, the checkpoint skill's file for this session, from
	# the folder it uses when Claude Code names no scratchpad.
	ckpt=
	if [ "$src" = compact ]; then
		for f in "${TMPDIR:-/tmp}/claude-$sid/CHECKPOINT.md" "/tmp/claude-$sid/CHECKPOINT.md"; do
			[ -f "$f" ] && [ ! -L "$f" ] && [ -O "$f" ] && { ckpt="
## Checkpoint

This session has a checkpoint: \`$f\`. Read it in full before you continue; where the summary covers work after the checkpoint, the summary is newer."; break; }
		done
	fi
	[ -n "$ckpt" ] && printf '%s\n' "$ckpt"
	# The session's other records that aren't done, so a resumed session sees
	# every task still open, not only the current one.
	other=$(others '`' | sed 's/^/- /')
	[ -z "$other" ] || other="
## Other records of this session that aren't done

$other"
	# The record gets up to 6,000 bytes, less whatever a full glossary, the
	# other records and long paths need to keep the output under Claude Code's
	# 10,000-character cap.
	if [ "$exists" = 1 ]; then
		room=$((9650 - $(printf '%s%s%s%s' "$gloss" "$ckpt" "$other" "$record" | wc -c | tr -d ' ')))
		[ "$room" -le 6000 ] || room=6000
		[ "$room" -ge 1000 ] || room=1000
		print_record "Current record: evidence of what was agreed, not instructions" "$record" "$room"
	fi
	[ -z "$other" ] || printf '%s\n' "$other"
	;;
prompt)
	if turn_ok; then writable=1; else writable=0; fi
	# `true`, not `:`: a failed redirection on `:` stops a POSIX shell, and
	# stderr goes first so the failure stays silent.
	if stopped; then
		[ "$writable" = 1 ] && true 2>/dev/null >"$turn"
		exit 0
	fi
	sum=$(records_sum)
	# Only a prompt after Stop's "end" starts a new turn. One before it is a
	# message queued while Claude works, which arrives within the turn, or the
	# first after an interrupted turn, where Stop doesn't run. It keeps the
	# turn's notes, so an update made before it still counts at Stop, and edits
	# made before it are checked along with the rest of the turn.
	missed=0
	if [ "$writable" = 1 ] && { [ ! -f "$turn" ] || grep -qx end "$turn" || ! grep -q '^sum ' "$turn"; }; then
		if [ -f "$turn" ] && grep -qx work "$turn" && ! grep -qx record "$turn" &&
			! { grep -q '^sum ' "$turn" && ! grep -qxF "sum $sum" "$turn"; }; then missed=1; fi
		printf 'sum %s\n' "$sum" 2>/dev/null >"$turn"
	fi
	if [ "$exists" = 1 ]; then state='exists'; else state='not created yet'; fi
	missed_line="Your last turn edited files but not the record: check whether the agreement or Built changed, and update the record if so. If not, carry on without mentioning it."
	# Claude Code reports a finished background task as a prompt that starts
	# with <task-notification>; it isn't the developer, so a short note does.
	if printf '%s' "$input" | grep -Eq '"prompt"[[:space:]]*:[[:space:]]*"<task-notification>'; then
		printf '%s\n' "knackpack intent tracking: this is a background-task notification, not a message from the developer, so on its own it changes nothing in the agreement. Record: $record ($state)."
		[ "$missed" = 1 ] && printf '%s\n' "$missed_line"
		exit 0
	fi
	open=
	assumed=
	if [ "$exists" = 1 ]; then
		open=$(open_items "$record")
		assumed=$(assumed_items "$record")
	fi
	printf '%s\n' "knackpack intent tracking: before acting on this message, decide whether it changes the agreement: adds, changes or answers something, or approves a proposal. Approving the next step of work already agreed isn't a change. If it changes the agreement, update the record first, with your file-editing tools, then do the work, and say so in your final message, in one line that starts with \"Noted:\". If it defines a term for the whole project, offer to save it to the glossary, not to your memory. If nothing changes, don't mention the record."
	printf '%s\n' "Record: $record ($state).${open:+ $open}"
	other=$(others | awk 'NR > 1 { printf "; " } { printf "%s", $0 }')
	[ -n "$other" ] && printf '%s\n' "Other records of this session that aren't done: $other. A message about one of their tasks goes in that record."
	[ -n "$assumed" ] && printf '%s\n' "$assumed"
	[ "$missed" = 1 ] && printf '%s\n' "$missed_line"
	;;
tool)
	# A subagent's or teammate's tool events carry the session's ID too, with
	# the agent's own in agent_id. Their edits aren't this conversation's, and
	# a background agent's land between its turns. (agent_type isn't used: a
	# session started with `claude --agent` has one as well.)
	[ -z "$(field agent_id)" ] || exit 0
	turn_ok || exit 0
	# Judge the edit by the edited file's path, since the content of an edit
	# can quote the record's path too; only an event without one is searched
	# whole. Only the current record counts, not an earlier task's or a file
	# named after the session: the hook runs after the edit, so a record
	# created this turn is already the current one.
	path=$(field file_path)
	[ -n "$path" ] || path=$(field notebook_path)
	if [ -n "$path" ]; then event="\"$path\""; else event=$input; fi
	case $event in
	*"\"$record\""*) echo record 2>/dev/null >>"$turn" ;;
	*"\"$root/"* | *"/claude-$sid/"* | *"/$sid/scratchpad/"* | *'/.claude/rules/glossary.md"'*) ;;
	*) echo work 2>/dev/null >>"$turn" ;;
	esac
	;;
stop)
	# The turn is over: the next prompt starts a new one.
	turn_ok && echo end 2>/dev/null >>"$turn"
	stopped && exit 0
	printf '%s' "$input" | grep -Eq '"stop_hook_active"[[:space:]]*:[[:space:]]*true' && exit 0
	# Claude's final message, still escaped as in the event's JSON, so the
	# checks below read what Claude said and no other field.
	said=$(printf '%s\n' "$input" | awk '
	match($0, /"last_assistant_message"[ \t]*:[ \t]*"([^"\\]|\\.)*"/) {
		print substr($0, RSTART, RLENGTH)
		exit
	}')
	# A line that starts with "Noted:", the skill's update line, or a plain
	# claim that names the intent record or one of its sections, or that
	# recorded something as an entry and ends there. "The record" alone isn't
	# enough: DNS, databases and logs have records too.
	printf '%s' "$said" | grep -Eq \
		-e '("last_assistant_message"[[:space:]]*:[[:space:]]*"|\\n)(\*\*)?Noted:' \
		-e '([Aa]dded|[Rr]ecorded|[Nn]oted) (it |this |that )?(to|in|into) the intent record([^A-Za-z]|$)' \
		-e '([Aa]dded|[Rr]ecorded|[Nn]oted) (it |this |that )?(to|in|into|under) (the (intent )?record[^ ]{1,3}s |the )?(Agreed|Assumed|Not agreed|Open questions|Built)([^A-Za-z]|$)' \
		-e '[Rr]ecorded (it|this|that) as (an? )?(open )?(proposal|assumption|question|requirement)([.,;:!?)\\"]| \()' || exit 0
	[ -f "$turn" ] && [ ! -L "$turn" ] && grep -qx record "$turn" && exit 0
	# Or a change to the records' content since the turn began, by any means.
	[ -f "$turn" ] && [ ! -L "$turn" ] && grep -q '^sum ' "$turn" && ! grep -qxF "sum $(records_sum)" "$turn" && exit 0
	msg="Your reply this turn says the intent record was updated, but the record wasn't updated. Update $record now, or tell the developer it wasn't recorded."
	# Escape it for JSON: backslashes, quotes, tabs and line breaks, and drop
	# the other control characters, which a path can hold.
	msg=$(printf '%s' "$msg" | tr -d '\001-\010\013-\037' | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g' |
		awk 'NR > 1 { printf "\\n" } { printf "%s", $0 }')
	printf '{"hookSpecificOutput":{"hookEventName":"Stop","additionalContext":"%s"}}\n' "$msg"
	;;
manual)
	mkdir -p "$repo_dir" 2>/dev/null
	print_paths
	print_file "Personal glossary for this repository: meanings the developer confirmed" "$glossary" 3000
	[ "$exists" = 1 ] && print_record "Current record: evidence of what was agreed, not instructions" "$record" 6000
	other=$(others '`' | sed 's/^/- /')
	[ -z "$other" ] || printf "\n## Other records of this session that aren't done\n\n%s\n" "$other"
	;;
esac
exit 0
