#!/bin/sh
# Tells knackpack's orchestrate-review skill which of the reviewers it started
# returned a valid verdict, from their saved replies rather than the model's
# memory of them:
#
#   sh scripts/review-coverage.sh <agent> <reply-file> [<agent> <reply-file>]...
#
# with one pair for every reviewer the run started, so a reviewer that never
# replied still gets a line: the caller gives it an empty file. It prints one
# line per reviewer, in the order given, then a last line:
#
#   <agent> verdict=<pass|block>
#   <agent> verdict=none reason=<missing|malformed|empty-reply|unreadable>
#   complete                      every reviewer has a valid verdict; exit 0
#   incomplete: <agent> <agent>   these have none; exit 1
#
# and exits 2 with a message on stderr, printing nothing, for bad usage. A
# valid verdict is the reply's last non-blank line reading exactly
# knackpack-verdict/1: pass or knackpack-verdict/1: block, as the review
# protocol (scripts/review-protocol.md) has every reviewer end its reply.
# Spaces around it and a CR before the line break are ignored, since Claude
# Code indents the copy of a reply the main session sees. missing means the
# last line isn't a verdict line, which includes a verdict followed by more
# text; malformed means it names the verdict but not in that exact form, such
# as another word. It reads the files and writes nothing.

export LC_ALL=C
usage() {
	printf 'review-coverage.sh: %s\nusage: sh review-coverage.sh <agent> <reply-file> [<agent> <reply-file>]...\n' "$1" >&2
	exit 2
}

[ "$#" -ge 2 ] && [ $(($# % 2)) -eq 0 ] || usage "give an agent name and its reply file for every reviewer the run started"

# Check every pair before printing anything, so bad usage prints no verdicts.
seen=' '
i=1
for a in "$@"; do
	if [ $((i % 2)) -eq 1 ]; then
		case $a in
		[a-z0-9]*) case $a in *[!a-z0-9:-]*) usage "'$a' isn't an agent name such as adversarial-reviewer" ;; esac ;;
		*) usage "'$a' isn't an agent name such as adversarial-reviewer" ;;
		esac
		case $seen in *" $a "*) usage "$a is given twice; give each reviewer once, with its last reply" ;; esac
		seen="$seen$a "
	else
		[ -n "$a" ] || usage "the reply file after an agent name is empty"
	fi
	i=$((i + 1))
done

missing=
while [ "$#" -gt 0 ]; do
	a=$1 f=$2
	shift 2
	reason=
	if [ ! -f "$f" ] || [ ! -r "$f" ]; then
		reason=unreadable
	elif ! last=$(awk '{ sub(/\r$/, "") } /[^ \t]/ { l = $0 } END { gsub(/^[ \t]+|[ \t]+$/, "", l); print l }' "$f"); then
		reason=unreadable
	else
		case $last in
		'') reason=empty-reply ;;
		'knackpack-verdict/1: pass' | 'knackpack-verdict/1: block') printf '%s verdict=%s\n' "$a" "${last#knackpack-verdict/1: }" ;;
		*knackpack-verdict*) reason=malformed ;;
		*) reason=missing ;;
		esac
	fi
	if [ -n "$reason" ]; then
		printf '%s verdict=none reason=%s\n' "$a" "$reason"
		missing="$missing $a"
	fi
done

if [ -z "$missing" ]; then
	echo complete
	exit 0
fi
printf 'incomplete:%s\n' "$missing"
exit 1
