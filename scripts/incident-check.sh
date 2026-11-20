#!/bin/sh
# Decides whether knackpack's fix-incident skill may start changing code for
# an incident whose diagnosis is the given ROOT-CAUSE.md:
#
#   sh scripts/incident-check.sh <path to ROOT-CAUSE.md>
#
# It prints one line and changes nothing:
#
#   approved <sha256>   the caller's KNACKPACK_INCIDENT_APPROVED_SHA256 matches
#   ask <sha256>        no approval was passed, so the person must approve it
#   refused: <reason>   don't fix anything
#
# and exits 1 only when it refused. The SHA-256 is of the text a tool reads:
# with KNACKPACK_DOCS=repo, the file as committed at HEAD, which must also be
# the file on disk; otherwise, the file. A tool that drives the incident steps
# approves that text and passes its hash in the variable; a person approves
# in the session instead, so a run with no one to ask, such as claude -p, and
# no hash is refused. A repository mustn't approve a diagnosis for someone
# who didn't, so the variable is refused when the repository's own settings
# may set it (scripts/repo-settings.sh).
#
# Like commit-docs.sh, it's a check for an agent that follows knackpack's
# rules, not a security boundary: an agent that can run commands can skip it,
# so a tool that must enforce approval blocks edits itself.

export LC_ALL=C
unset CDPATH
refuse() {
	printf 'refused: %s\n' "$1"
	exit 1
}

[ "$#" -eq 1 ] || refuse "give one path, the incident's ROOT-CAUSE.md"
case ${1##*/} in ROOT-CAUSE.md) ;; *) refuse "$1 isn't a ROOT-CAUSE.md" ;; esac
{ [ -f "$1" ] && [ ! -L "$1" ]; } || refuse "$1 doesn't exist or isn't a regular file, so there's no diagnosis to fix"
d=$(cd -P -- "$(dirname -- "$1")" && pwd -P) || refuse "can't enter the folder that holds $1"
p=$d/ROOT-CAUSE.md

# The word on the first non-blank line under "## Status".
status=$(awk '/^## Status[ \t]*$/ { s = 1; next } s && /^#/ { exit } s && NF { print $1; exit }' "$p") ||
	refuse "can't read $p"
[ "$status" = CONFIRMED ] || refuse "its Status is ${status:-missing}, not CONFIRMED, so no cause is confirmed and nothing may be fixed yet"

sum() { # stdin's SHA-256, in lowercase hex
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum | awk '{ print $1 }'
	elif command -v shasum >/dev/null 2>&1; then
		shasum -a 256 | awk '{ print $1 }'
	elif command -v openssl >/dev/null 2>&1; then
		openssl dgst -sha256 -r | awk '{ print $1 }'
	else
		return 1
	fi
}

if [ "${KNACKPACK_DOCS:-}" = repo ]; then
	top=$(cd "$d" && git rev-parse --show-toplevel 2>/dev/null) && top=$(cd -P -- "$top" && pwd -P) ||
		refuse "KNACKPACK_DOCS=repo is set, but $p isn't in a git repository, so it isn't committed"
	rel=${p#"$top"/}
	git -C "$top" cat-file -e "HEAD:$rel" 2>/dev/null ||
		refuse "$rel isn't committed at HEAD; commit it with commit-docs.sh first, since what's approved is the committed text"
	git -C "$top" diff --quiet HEAD -- "$rel" 2>/dev/null ||
		refuse "$rel differs from its committed text, and an edit after approval voids the approval; commit the change as a new revision for approval, or restore it with git checkout HEAD -- $rel"
	h=$(git -C "$top" cat-file blob "HEAD:$rel" | sum)
else
	h=$(sum <"$p")
fi
[ -n "$h" ] || refuse "found no sha256sum, shasum or openssl to hash $p"

# An eval passes only EVAL_* variables, so its cases set the approval as
# EVAL_KNACKPACK_INCIDENT_APPROVED_SHA256; the settings check below matches
# that name too, since it contains the other.
if [ -n "${KNACKPACK_INCIDENT_APPROVED_SHA256+x}" ]; then
	approved=$KNACKPACK_INCIDENT_APPROVED_SHA256
elif [ -n "${EVAL_KNACKPACK_INCIDENT_APPROVED_SHA256+x}" ]; then
	approved=$EVAL_KNACKPACK_INCIDENT_APPROVED_SHA256
else
	unset approved
fi
if [ -n "${approved+x}" ]; then
	lib=$(dirname -- "$0")/repo-settings.sh
	[ -f "$lib" ] || refuse "can't find repo-settings.sh beside this script"
	. "$lib"
	for where in "${CLAUDE_PROJECT_DIR:-.}" "$d"; do
		hit=$(cd -- "$where" 2>/dev/null && settings_naming KNACKPACK_INCIDENT_APPROVED_SHA256) ||
			refuse "can't list the settings files of the repository that holds $where"
		[ -z "$hit" ] ||
			refuse "$hit names KNACKPACK_INCIDENT_APPROVED_SHA256 or uses a \\u escape that could spell it, and a repository's settings can't approve a diagnosis; pass it from the tool that approved it, or approve in the session"
	done
	want=$(printf '%s' "$approved" | tr '[:upper:]' '[:lower:]')
	[ "$want" = "$h" ] ||
		refuse "the approved SHA-256 is ${want:-empty}, but the diagnosis now hashes to $h, so what was approved isn't this text"
	printf 'approved %s\n' "$h"
	exit 0
fi

# The same test as the hooks: claude -p runs as sdk-cli and a background
# session sets the attended flag to 0, and neither has a person to ask.
case ${CLAUDE_CODE_SESSION_ATTENDED:-}:${CLAUDE_CODE_ENTRYPOINT:-} in
0:* | :sdk-*) refuse "no approval was passed in KNACKPACK_INCIDENT_APPROVED_SHA256, and this session has no one to ask; approve the diagnosis in an attended session, or pass the hash of the approved text" ;;
esac
printf 'ask %s\n' "$h"
