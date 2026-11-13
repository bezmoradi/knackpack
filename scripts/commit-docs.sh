#!/bin/sh
# Commits one document that knackpack's challenge-requirements or
# plan-implementation skill wrote into the repository because
# KNACKPACK_DOCS=repo asked for it, so a tool that reads the committed
# documents, such as a push gate, can read it from git:
#
#   sh scripts/commit-docs.sh .knackpack/<task>/REQUIREMENTS.md
#   sh scripts/commit-docs.sh .knackpack/<task>/PLAN.md
#
# It rewrites .knackpack/feature.json to name the document's folder, then
# commits exactly those two files on the current branch, through the
# repository's own commit hooks, from an index of its own: HEAD plus the two
# files. The repository's index, with the developer's other staged work, is
# touched only after the commit is made and checked, and then only for those
# two paths, so a failed or interrupted run leaves it as it was. A commit hook
# can stage more files or change the document, so it checks the commit too,
# and takes it back when it holds anything else. It also refuses when the
# repository's own settings switch the mode on. It prints one line,
# "committed ...", "already committed ..." or "not committed: <reason>", and
# exits 1 only when it didn't commit. hooks/challenge.sh tells Claude when and
# how to run it.
#
# It's a convenience for an agent that follows knackpack's rules, not a
# security boundary: whatever can run commands in the repository can commit
# without it, so a tool that reads the committed documents checks the commits
# itself.

export LC_ALL=C
unset CDPATH
fail() {
	printf 'not committed: %s\n' "$1"
	exit 1
}

[ "${KNACKPACK_DOCS:-}" = repo ] || fail "KNACKPACK_DOCS isn't set to repo, so nothing goes into the repository"
# --check runs only the checks below on the repository's settings and writes
# nothing; hooks/challenge.sh runs it before printing the rules, so a
# repository's own setting never leads Claude to write a copy at all. Outside
# a git repository it passes, since the rules then commit nothing anyway.
check=
[ "${1:-}" = --check ] && check=1
[ -n "$check" ] || [ "$#" -eq 1 ] || fail "give one path, .knackpack/<task>/REQUIREMENTS.md or .knackpack/<task>/PLAN.md"
# Each of these would point git at another index, repository or object store.
for v in GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR; do
	eval "isset=\${$v+x}"
	[ -z "$isset" ] || fail "$v is set, so git could commit somewhere other than this checkout; run it without $v"
done
top=$(git rev-parse --show-toplevel 2>/dev/null) && top=$(cd -P -- "$top" && pwd -P) || {
	[ -z "$check" ] || exit 0
	fail "this folder isn't in a git repository"
}

# A repository mustn't switch the mode on for someone who didn't choose it, so
# refuse when its own settings may set KNACKPACK_DOCS: .claude/settings.json in
# this folder or any above it up to the top level, and every
# .claude/settings.json or .claude/settings.local.json git tracks anywhere in
# the repository, since Claude Code counts a tracked local file as the
# repository's too and may have started in any folder. JSON can spell any
# letter of a key as a \u escape, so a file that uses one counts as setting
# it. A person's environment, user settings, --settings or untracked local
# settings still can.
names() { # <file>: whether it may name the variable
	[ -f "$1" ] && grep -q -F -e KNACKPACK_DOCS -e '\u' -- "$1" 2>/dev/null
}
refuse() {
	fail "$1 names KNACKPACK_DOCS or uses a \\u escape that could spell it, and a repository's settings can't switch committed documents on; set it in your own environment, your user settings or an untracked .claude/settings.local.json"
}
dir=$(pwd -P) || fail "can't tell which folder this is"
while :; do
	s=$dir/.claude/settings.json
	! names "$s" || refuse "${s#"$top"/}"
	[ "$dir" != "$top" ] || break
	case $dir in "$top"/*) dir=${dir%/*} ;; *) break ;; esac
done
tracked=$(git -C "$top" -c core.quotepath=off ls-files -- ':(glob)**/.claude/settings.json' ':(glob)**/.claude/settings.local.json' 2>/dev/null) ||
	fail "can't list the repository's settings files"
hit=$(printf '%s\n' "$tracked" | while IFS= read -r f; do
	[ -n "$f" ] && names "$top/$f" && { printf '%s\n' "$f"; break; }
done)
[ -z "$hit" ] || refuse "$hit"
[ -z "$check" ] || exit 0

# The document, relative to the top level, however it was given: resolved
# from where the script was run, with symbolic links followed (cd -P), since
# git gives the top level that way (on macOS, /var is /private/var), and
# with ".." taken after them, as the system does when it opens the path.
d=$(cd -P -- "$(dirname -- "$1")" 2>/dev/null && pwd -P) || fail "$1 isn't in an existing folder"
p=$d/${1##*/}
case $p in
"$top"/*) p=${p#"$top"/} ;;
*) fail "$1 isn't inside the repository, $top" ;;
esac
cd -P -- "$top" || fail "can't enter the repository's top level, $top"
case $p in
.knackpack/*/REQUIREMENTS.md) kind=requirements ;;
.knackpack/*/PLAN.md) kind=plan ;;
*) fail "$p isn't .knackpack/<task>/REQUIREMENTS.md or .knackpack/<task>/PLAN.md" ;;
esac
task=${p#.knackpack/}
task=${task%/*}
case $task in
'' | -* | *[!a-z0-9-]*) fail "the task folder \"$task\" must match ^[a-z0-9][a-z0-9-]{0,63}\$" ;;
esac
[ "${#task}" -le 64 ] || fail "the task folder \"$task\" is longer than 64 characters"

# Real files and folders only: through a symbolic link, the write below or
# git would reach outside the repository.
for d in .knackpack ".knackpack/$task"; do
	{ [ -d "$d" ] && [ ! -L "$d" ]; } || fail "$d isn't a folder"
done
{ [ -f "$p" ] && [ ! -L "$p" ]; } || fail "$p isn't a file"
f=.knackpack/feature.json
{ [ ! -e "$f" ] && [ ! -L "$f" ]; } || { [ -f "$f" ] && [ ! -L "$f" ]; } || fail "$f isn't a file"

branch=$(git symbolic-ref -q --short HEAD) || fail "HEAD is detached, so the commit would be on no branch"
# Committing in the middle of one of these would mix the document into it.
for x in MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD rebase-merge rebase-apply; do
	[ ! -e "$(git rev-parse --git-path "$x")" ] ||
		fail "a merge, cherry-pick, revert or rebase is in progress in this checkout; finish or abort it first"
done
[ -z "$(git ls-files -u)" ] || fail "the index has unresolved conflicts; resolve them first"
! git ls-files -t -- "$p" "$f" | grep -q '^S ' ||
	fail "the sparse checkout leaves out .knackpack/, so git can't commit there; add .knackpack to it first"

# The document may be pushed to a public repository, so it mustn't name paths
# from this machine: the home folder, the repository's own path, the
# temporary folder, knackpack's state folder, or a user folder on macOS or
# Windows. Each is matched where a path starts and ends, ignoring case and
# with backslashes read as slashes, so /Users/me.md doesn't match a home of
# /Users/me and cmd/root/ doesn't match one of /root. Relative values, such as
# a TMPDIR of tmp, name no place and are skipped. "~" and "$HOME" are left
# alone: they name no one.
leaks() {
	KP_TOP=$top awk '
	function norm(s) {
		gsub(/\\/, "/", s)
		gsub(/\/\/+/, "/", s)
		return s
	}
	function add(s, open) {
		s = norm(s)
		while (length(s) > 1 && substr(s, length(s)) == "/") s = substr(s, 1, length(s) - 1)
		if (s !~ /^\// && s !~ /^[A-Za-z]:\//) return
		if (s == "/" || s == "/tmp" || s ~ /^[A-Za-z]:\/?$/) return
		k++
		need[k] = tolower(s)
		name[k] = s
		prefix[k] = open
	}
	function inword(c) { return c ~ /[A-Za-z0-9_-]/ }
	function report(what) {
		if (!(what in seen)) { order[++m] = what; seen[what] = "" }
		seen[what] = seen[what] " " NR
	}
	BEGIN {
		add(ENVIRON["HOME"]); add(ENVIRON["USERPROFILE"]); add(ENVIRON["KP_TOP"])
		add(ENVIRON["TMPDIR"]); add(ENVIRON["XDG_STATE_HOME"])
		add("/private/var/folders"); add("/var/folders"); add("/tmp/claude-", 1)
	}
	{
		line = norm($0)
		low = tolower(line)
		hit = 0
		for (i = 1; i <= k; i++) {
			from = 1
			while ((j = index(substr(low, from), need[i])) > 0) {
				at = from + j - 1
				before = at > 1 ? substr(low, at - 1, 1) : ""
				after = substr(low, at + length(need[i]), 1)
				if (!inword(before) && before != "." && (prefix[i] || !inword(after))) { report(name[i]); hit = 1; break }
				from = at + 1
			}
		}
		if (hit) next
		mac = line
		gsub(/\/Users\/Shared/, "", mac)
		gsub(/[A-Za-z]:\/[Uu][Ss][Ee][Rr][Ss]\/([Pp][Uu][Bb][Ll][Ii][Cc]|[Dd][Ee][Ff][Aa][Uu][Ll][Tt])/, "", mac)
		if (match(mac, /(^|[^A-Za-z0-9_.-])\/Users\/[A-Za-z0-9]/)) report("/Users/<name>")
		win = low
		gsub(/[a-z]:\/users\/(public|default)/, "", win)
		if (match(win, /(^|[^a-z0-9_.-])[a-z]:\/users\/[a-z0-9]/)) report("C:\\Users\\<name>")
	}
	END { for (i = 1; i <= m; i++) printf " %s (line%s)", order[i], seen[order[i]] }'
}
found=$(leaks <"$p") || fail "can't read $p"
[ -z "$found" ] || fail "$p names paths from this machine:$found. Cite files in the repository by their repository path and leave the rest out"

ignored=$(git check-ignore -- "$p" "$f" 2>/dev/null | tr '\n' ' ')
[ -z "$ignored" ] || fail "git ignores ${ignored% }, so it can't be committed"

# Work files beside git's own, where no commit hook would add them, and a
# lock, so two runs in one checkout can't mix their files. A lock whose
# process is gone, as after a kill, is taken over.
gp() {
	x=$(git rev-parse --git-path "$1") || return 1
	case $x in /*) printf '%s\n' "$x" ;; *) printf '%s\n' "$top/$x" ;; esac
}
lock=$(gp knackpack-commit-docs.lock) && idx=$(gp knackpack-commit-docs.index) &&
	bak=$(gp knackpack-commit-docs.feature.json) && new=$(gp knackpack-commit-docs.new) &&
	ri=$(gp index) || fail "can't find the repository's git folder"
if ! mkdir "$lock" 2>/dev/null; then
	pid=$(cat "$lock/pid" 2>/dev/null)
	case $pid in
	'' | *[!0-9]*) fail "another run of this script may be committing in this checkout; if none is, remove $lock and run it again" ;;
	esac
	! kill -0 "$pid" 2>/dev/null || fail "another run of this script (process $pid) is committing in this checkout; run it again once it ends"
	rm -rf "$lock" && mkdir "$lock" 2>/dev/null || fail "can't take over the lock $lock"
fi
printf '%s\n' "$$" >"$lock/pid"

# feature.json as it was, put back when nothing is committed.
restore() {
	if [ -n "$had" ]; then mv -f -- "$bak" "$f"; else rm -f -- "$f"; fi
}
takeback() {
	if [ -n "$head" ]; then
		git update-ref -m "commit-docs.sh: take back $c" HEAD "$head" "$c"
	else
		git update-ref -d HEAD "$c"
	fi || fail "$1, and taking commit $c back failed; check git log and git status"
	restore
	fail "$1, so the commit was taken back"
}
# After the commit, judged by where HEAD went rather than by git's exit
# status: what the commit holds, what feature.json in it names, and whether
# the text committed names a path from this machine, as a clean filter could
# make it.
finish() {
	state=checking
	trap '' HUP INT TERM
	c=$(git rev-parse -q --verify HEAD)
	if [ "$c" = "$head" ]; then
		restore
		fail "git commit failed: $(printf '%s\n' "$1" | tail -n 3 | tr '\n' ' ')"
	fi
	[ "$(git rev-parse -q --verify "$c^" 2>/dev/null)" = "$head" ] ||
		fail "HEAD moved to $c, which isn't one commit on top of $head, so nothing was taken back; check git log"
	if [ -n "$head" ]; then
		files=$(git diff-tree -r --name-only "$head" "$c")
	else
		files=$(git diff-tree -r --root --no-commit-id --name-only "$c")
	fi
	extra=$(printf '%s\n' "$files" | grep -vxF -e "$p" -e "$f" | tr '\n' ' ')
	if [ -z "$files" ]; then
		if [ -n "$head" ]; then git update-ref -m "commit-docs.sh: take back $c" HEAD "$head" "$c"; else git update-ref -d HEAD "$c"; fi ||
			fail "the commit hooks left nothing to commit, and taking the empty commit $c back failed; check git log"
		restore
		printf 'already committed in %s on %s, unchanged once the commit hooks ran: %s\n' "$(git log -1 --format=%h -- "$p")" "$branch" "$p"
		exit 0
	fi
	[ -z "$extra" ] || takeback "the repository's commit hooks added ${extra% } to the commit"
	git cat-file blob "$c:$f" 2>/dev/null | grep -q "\"\\.knackpack/$task\"" ||
		takeback "the commit hooks left $f out of the commit or changed the folder it names"
	found=$(git cat-file blob "$c:$p" | leaks)
	[ -z "$found" ] || takeback "$p as committed names paths from this machine:$found, which a clean filter or commit hook added"
	short=$(git rev-parse --short "$c")
	note=
	[ "$(git rev-parse "$c:$p")" = "$written" ] ||
		note="; $p as committed differs from the file written, changed by a commit hook or git filter, so read it with git show $short:$p"
	git reset -q -- "$p" "$f" 2>/dev/null ||
		note="$note; git couldn't update the index for $p and $f, so run git reset -q -- $p $f"
	rm -f "$bak"
	printf 'committed %s on %s: %s and %s%s\n' "$short" "$branch" "$p" "$f" "$note"
	exit 0
}
interrupted() {
	trap - HUP INT TERM
	case $state in
	committing) finish "interrupted" ;;
	written) restore ;;
	esac
	fail "interrupted before the commit was made"
}

state=start
trap 'rm -f "$idx" "$new" "$bak"; rm -rf "$lock"' EXIT
trap interrupted HUP INT TERM

had=
if [ -f "$f" ]; then
	had=1
	cp -- "$f" "$bak" || fail "can't save a copy of $f"
fi
# A new file, moved into place, so a hard link to feature.json from outside
# the repository keeps its own content.
printf '{"feature_directory": ".knackpack/%s"}\n' "$task" >"$new" && mv -f -- "$new" "$f" || {
	restore
	fail "can't write $f"
}
state=written

# The commit's own index: the repository's index, for its file timestamps,
# brought back to HEAD, then the two files.
head=$(git rev-parse -q --verify HEAD)
err=$({
	{ [ ! -f "$ri" ] || cp -- "$ri" "$idx"; } &&
		if [ -n "$head" ]; then GIT_INDEX_FILE=$idx git read-tree -m HEAD; else GIT_INDEX_FILE=$idx git read-tree --empty; fi &&
		GIT_INDEX_FILE=$idx git add -- "$p" "$f"
} 2>&1) || {
	restore
	fail "git couldn't stage $p and $f: $(printf '%s\n' "$err" | tail -n 3 | tr '\n' ' ')"
}
written=$(git hash-object --no-filters -- "$p")
if [ -n "$head" ] && GIT_INDEX_FILE=$idx git diff --cached --quiet; then
	printf 'already committed in %s on %s, unchanged: %s\n' "$(git log -1 --format=%h -- "$p")" "$branch" "$p"
	exit 0
fi

state=committing
out=$(GIT_INDEX_FILE=$idx git commit -q -m "docs(knackpack): $kind for $task" 2>&1)
finish "$out"
