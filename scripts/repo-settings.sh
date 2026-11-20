# shellcheck shell=sh
# Sourced, not run: scripts/commit-docs.sh and scripts/incident-check.sh read
# it with ".", so one rule decides, for both, whether a repository's own
# settings may set one of knackpack's environment variables. A repository
# mustn't switch committed documents on, or approve an incident's diagnosis,
# for someone who didn't choose it.
#
# settings_naming <variable>, run in a folder inside a git work tree, prints
# the first settings file, relative to the top level, that may set the
# variable, and nothing when none does or the folder isn't in a work tree. It
# returns 1 only when it can't tell. A file may set it when it names the
# variable or uses a \u escape, since JSON can spell any letter of a key that
# way. The files are .claude/settings.json in this folder and each one above
# it up to the top level, and every .claude/settings.json or
# .claude/settings.local.json git tracks anywhere in the repository, since
# Claude Code counts a tracked local file as the repository's too and may
# have started in any folder. A person's environment, user settings,
# --settings and untracked local settings still can.

settings_file_names() { # <file> <variable>: whether the file may name it
	[ -f "$1" ] && grep -q -F -e "$2" -e '\u' -- "$1" 2>/dev/null
}

settings_naming() { # <variable>
	_kp_top=$(git rev-parse --show-toplevel 2>/dev/null) || return 0
	_kp_top=$(cd -P -- "$_kp_top" && pwd -P) && _kp_dir=$(pwd -P) || return 1
	while :; do
		_kp_s=$_kp_dir/.claude/settings.json
		if settings_file_names "$_kp_s" "$1"; then
			printf '%s\n' "${_kp_s#"$_kp_top"/}"
			return 0
		fi
		[ "$_kp_dir" != "$_kp_top" ] || break
		case $_kp_dir in "$_kp_top"/*) _kp_dir=${_kp_dir%/*} ;; *) break ;; esac
	done
	_kp_tracked=$(git -C "$_kp_top" -c core.quotepath=off ls-files -- ':(glob)**/.claude/settings.json' ':(glob)**/.claude/settings.local.json' 2>/dev/null) ||
		return 1
	printf '%s\n' "$_kp_tracked" | while IFS= read -r _kp_f; do
		[ -n "$_kp_f" ] && settings_file_names "$_kp_top/$_kp_f" "$1" && { printf '%s\n' "$_kp_f"; break; }
	done
	return 0
}
