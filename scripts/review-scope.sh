#!/bin/sh
# Resolves a knackpack review's scope the same way for every reviewer, so the
# reviewers of one combined review read the same snapshot against the same
# base: it records the repository's starting state, builds the snapshot of
# the work under review, finds the target branch, fetches it without a prompt
# and finds the merge base. scripts/review-protocol.md, steps 2 to 4, gives
# the same rules for a reviewer that can't run it. Run it from inside the
# repository under review:
#
#   sh review-scope.sh [--own] <dir> [<target>]
#   sh review-scope.sh --after <dir>
#
# <dir> is the reviewer's scratch folder, made with mktemp -d outside the
# repository. <target> is what the user named, if anything: a branch (name or
# <remote>/<name>), a tag or commit, a range A..B or A...B, or a pull request
# number (12 or #12), which it reads with gh. --own says the user said the
# checked-out branch is theirs. --after repeats the state record for the
# check at the end of a review and says whether anything changed.
#
# It prints these lines, always in this order, with none where one doesn't
# apply, and saves them in <dir>/scope.txt:
#
#   repository=<top-level folder>
#   head=<HEAD commit>
#   branch=<checked-out branch>
#   target=<target branch, or what the user named>
#   target_source=named|pull-request|origin-head|remote-head|gh|none
#   remote=<remote name or URL the target came from>
#   target_commit=<commit the target resolved to>
#   refreshed=yes|no|not-applicable   whether the fetch brought it up to date
#   shallow=yes|no
#   filters=none|git-lfs|other   filters or fsmonitor in git config
#   state=full|head   what <dir>/before.txt records: all of it, or HEAD alone
#   state_file=<dir>/before.txt
#   snapshot=<tree or commit under review>
#   snapshot_kind=tree|commit
#   snapshot_source=working-tree|head|pull-request|range
#   base=<commit or tree to diff the snapshot against>
#   base_source=merge-base|pull-request|named|last-commit|empty-tree|head
#   pr=<pull request number>
#   files_changed=<files git diff <base> <snapshot> names>
#   note=<something the report must say>   zero or more
#   refused=<why uncommitted work isn't reviewed>   zero or one
#
# --after prints state_file=<dir>/after.txt, snapshot= and unchanged=yes|no.
# When it can't resolve the scope it prints error=<reason> last and exits 1;
# bad usage exits 2 with a message on stderr.
#
# It never changes the user's branch, index, files or config. It writes only
# in <dir>, in git's object store (building the snapshot tree), and when it
# fetches, in FETCH_HEAD and remote-tracking refs; it fetches no tags. Every
# network step is bounded: a minute for a fetch, 20 seconds for a lookup.

# test -O isn't POSIX, but dash and bash both have it. Before the first
# command, this directive covers the whole script.
# shellcheck disable=SC3067
export LC_ALL=C
unset CDPATH
umask 077

usage() {
	printf 'review-scope.sh: %s\nusage: sh review-scope.sh [--own] <dir> [<target>]\n       sh review-scope.sh --after <dir>\n' "$1" >&2
	exit 2
}
nl='
'
tab=$(printf '\t')
out=
put() { out="$out$1=$(printf '%s' "$2" | tr '\n\r\t' '   ')$nl"; }
notes=
note() { notes="${notes}note=$(printf '%s' "$1" | tr '\n\r\t' '   ')$nl"; }
die() {
	printf '%s%serror=%s\n' "$out" "$notes" "$(printf '%s' "$1" | tr '\n\r\t' '   ')"
	exit 1
}
hex() { printf '%s\n' "$1" | grep -Eqx '[0-9a-f]{40}|[0-9a-f]{64}'; }

mode=before own=
while [ "$#" -gt 0 ]; do
	case $1 in
	--after) mode=after ;;
	--own) own=1 ;;
	--) shift && break ;;
	-*) usage "unknown option $1" ;;
	*) break ;;
	esac
	shift
done
[ "$#" -ge 1 ] && [ "$#" -le 2 ] || usage "give the scratch folder and at most one target"
dir=$1 want=${2-}
[ "$mode" = after ] && [ -n "$want$own" ] && usage "--after takes only the scratch folder"
case $want in -*) usage "a target can't start with -" ;; esac

{ [ -d "$dir" ] && [ ! -L "$dir" ] && [ -O "$dir" ]; } || die "$dir isn't a folder of yours: make one with mktemp -d"
dir=$(cd -P -- "$dir" && pwd -P) || die "can't enter $dir"
top=$(git rev-parse --show-toplevel 2>/dev/null) && top=$(cd -P -- "$top" && pwd -P) ||
	die "this isn't inside a git repository's working tree, so there is nothing to diff"
case $dir/ in "$top"/*) die "$dir is inside the repository; use a folder made with mktemp -d outside it" ;; esac
cd "$top" || die "can't enter $top"

# Step 2's commands, exactly as the protocol gives them, writing to <file>.
record() {
	rm -f "$dir/index"
	cp "$(git rev-parse --git-path index)" "$dir/index" 2>/dev/null
	{
		git rev-parse -q --verify HEAD
		git for-each-ref --format='%(objectname) %(refname)' refs/heads refs/tags
		git rev-parse -q --verify refs/stash
		git worktree list --porcelain
		GIT_OPTIONAL_LOCKS=0 git status --porcelain=v2 --untracked-files=all
		GIT_INDEX_FILE=$dir/index git -c core.hooksPath=/dev/null add -A &&
			GIT_INDEX_FILE=$dir/index git -c core.hooksPath=/dev/null write-tree
	} >"$1" 2>"$dir/record.err"
}

if [ "$mode" = after ]; then
	[ -f "$dir/scope.txt" ] && [ -f "$dir/before.txt" ] || die "$dir has no scope.txt or before.txt: run review-scope.sh without --after first"
	if [ "$(sed -n 's/^state=//p' "$dir/scope.txt")" = head ]; then
		git rev-parse -q --verify HEAD >"$dir/after.txt"
	else
		record "$dir/after.txt" || die "couldn't record the state again: $(head -c 300 "$dir/record.err")"
	fi
	put state_file "$dir/after.txt"
	put snapshot "$(tail -n 1 "$dir/after.txt")"
	if cmp -s "$dir/before.txt" "$dir/after.txt"; then put unchanged yes; else put unchanged no; fi
	printf '%s' "$out"
	exit 0
fi

# Bounded network steps. A command runs with stdin from /dev/null and is
# stopped after <seconds>; the watchdog's output goes to /dev/null so a
# command substitution doesn't wait for it.
bounded() { # <seconds> <command>...
	bs=$1
	shift
	"$@" </dev/null &
	bp=$!
	(
		trap 'kill "$bw" 2>/dev/null; exit 0' TERM
		sleep "$bs" &
		bw=$!
		wait "$bw" && kill "$bp" 2>/dev/null
	) >/dev/null 2>&1 &
	bk=$!
	wait "$bp"
	br=$?
	kill "$bk" 2>/dev/null
	wait "$bk" 2>/dev/null
	return "$br"
}
ssh_cmd="${GIT_SSH_COMMAND:-$(git config core.sshCommand || echo ssh)} -o BatchMode=yes -o ConnectTimeout=15"
net() { # <seconds> <command>..., unable to ask for a password or passphrase
	ns=$1
	shift
	bounded "$ns" env GIT_ASKPASS= GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=never GH_PROMPT_DISABLED=1 GH_NO_UPDATE_NOTIFIER=1 \
		"GIT_SSH_COMMAND=$ssh_cmd" "$@"
}
# --no-tags keeps the fetch to FETCH_HEAD and remote-tracking refs. Without
# --no-recurse-submodules, git fetch reads the index to look for submodules
# and so runs core.fsmonitor (git 2.49).
fetch() { # <remote or URL> <ref>
	net 60 git -c core.hooksPath=/dev/null fetch --no-tags --no-recurse-submodules -q "$1" "$2" >/dev/null 2>&1
}
# The commit a fetch from a URL left in FETCH_HEAD for <branch>, read at once,
# since another reviewer's fetch can overwrite the file.
fetched() { # <branch>
	f=$(git rev-parse --git-path FETCH_HEAD) &&
		awk -F "$tab" -v b="branch '$1' of " 'index($3, b) == 1 { print $1; exit }' "$f" 2>/dev/null
}
commit_of() { git rev-parse -q --verify "$1^{commit}" 2>/dev/null; }
slug_of() { # owner/name of a GitHub URL
	printf '%s\n' "$1" | sed -n -e 's|^https://\([^@/]*@\)\{0,1\}github\.com/\([^/]*/[^/]*\)$|\2|p' \
		-e 's|^git@github\.com:\([^/]*/[^/]*\)$|\1|p' -e 's|^ssh://git@github\.com/\([^/]*/[^/]*\)$|\1|p' |
		sed -e 's|/$||' -e 's|\.git$||' | tr '[:upper:]' '[:lower:]'
}
remote_for() { # the remote whose URL is the GitHub repository <owner/name>
	for rr in $(git remote); do
		[ "$(slug_of "$(git config "remote.$rr.url")")" = "$1" ] && { printf '%s\n' "$rr"; return 0; }
	done
	return 1
}

head=$(git rev-parse -q --verify HEAD 2>/dev/null) || head=
branch=$(git symbolic-ref -q --short HEAD 2>/dev/null) || branch=
shallow=no
[ "$(git rev-parse --is-shallow-repository 2>/dev/null)" = true ] && shallow=yes
empty=$(git hash-object -t tree /dev/null) || die "git can't hash the empty tree"

# Filters and fsmonitor run code whenever git reads changed files. Git LFS's
# own filter runs the program installed here, so it doesn't count.
cfg=$(git config --get-regexp '^(filter\..*\.(clean|smudge|process)|core\.fsmonitor)$' 2>/dev/null)
risky=$(printf '%s\n' "$cfg" | awk 'NF && !/^filter\.lfs\.(clean|smudge|process) git-lfs / { print $1 }' | sort -u | tr '\n' ' ')
risky=${risky% }
filters=none
[ -n "$cfg" ] && filters=git-lfs
[ -n "$risky" ] && filters=other

# The remote that stands for origin: origin, else the one the branch tracks,
# else the only one.
remote=
if git config remote.origin.url >/dev/null 2>&1; then
	remote=origin
elif [ -n "$branch" ] && tr_=$(git config "branch.$branch.remote") && [ "$tr_" != . ] && git config "remote.$tr_.url" >/dev/null 2>&1; then
	remote=$tr_
elif [ "$(git remote | wc -l | tr -d ' ')" = 1 ]; then
	remote=$(git remote)
fi

target='' tsrc=none tremote='' tcommit='' refreshed=not-applicable
base='' bsrc='' snap='' kind='' ssrc='' pr='' refused=''

# Fetches <branch> from $tremote and sets tcommit and refreshed.
fetch_branch() { # <branch>
	if fetch "$tremote" "$1"; then
		refreshed=yes
		tcommit=$(commit_of "refs/remotes/$tremote/$1") || tcommit=$(fetched "$1")
	else
		refreshed=no
		tcommit=$(commit_of "refs/remotes/$tremote/$1") || tcommit=
		note "fetching $1 from $tremote failed or took over a minute, so the base wasn't refreshed${tcommit:+: it is the copy of the branch already here}"
	fi
}

is_pr() { case ${want#\#} in '' | *[!0-9]*) return 1 ;; esac; }
is_range() { case $want in *..*) return 0 ;; esac; return 1; }

if [ -n "$want" ] && is_pr; then
	# A pull request: its base branch, head and merge base, read with gh.
	n=${want#\#}
	pr=$n
	command -v gh >/dev/null 2>&1 || die "pull request $n can only be read with gh, which isn't installed"
	tries=0
	while :; do
		j=$(net 20 gh pr view "$n" --json baseRefName,baseRefOid,headRefOid,url --jq '[.baseRefName, .baseRefOid, .headRefOid, .url] | join(" ")' 2>/dev/null) ||
			die "gh couldn't read pull request $n (not signed in, no such pull request, or no network)"
		# shellcheck disable=SC2086 # the four fields hold no spaces
		set -- $j
		[ "$#" = 4 ] && hex "$2" && hex "$3" || die "gh gave pull request $n's fields in a form this can't read: $j"
		target=$1 boid=$2 hoid=$3
		repo=${4%/pull/*}
		tremote=$(remote_for "$(slug_of "$repo")") || tremote=$repo
		fetch "$tremote" "pull/$n/head" || true
		if fetch "$tremote" "$target"; then refreshed=yes; else refreshed=no; fi
		[ "$(git cat-file -t "$hoid" 2>/dev/null)" = commit ] && [ "$(git cat-file -t "$boid" 2>/dev/null)" = commit ] && break
		tries=$((tries + 1))
		[ "$tries" -ge 2 ] && die "pull request $n's head $hoid or base $boid didn't arrive from $tremote after two fetches"
	done
	[ "$refreshed" = no ] && note "fetching $target from $tremote failed or took over a minute, so the base branch wasn't refreshed"
	tsrc=pull-request tcommit=$boid
	base=$(git merge-base "$boid" "$hoid" 2>/dev/null) && hex "$base" ||
		die "pull request $n's head and base have no merge base here$([ "$shallow" = no ] || echo "; the repository is shallow, and deepening it (git fetch --unshallow) needs the user's permission")"
	bsrc=pull-request snap=$hoid kind=commit ssrc=pull-request
elif [ -n "$want" ] && is_range; then
	# A range: A..B diffs B against A, A...B against their merge base.
	target=$want tsrc=named
	case $want in
	*...*) a=${want%%...*} b=${want#*...} ;;
	*) a=${want%%..*} b=${want#*..} ;;
	esac
	a=$(commit_of "${a:-HEAD}") && b=$(commit_of "${b:-HEAD}") || die "$want isn't a range of commits here"
	case $want in
	*...*) base=$(git merge-base "$a" "$b" 2>/dev/null) && hex "$base" || die "the two ends of $want have no merge base" ;;
	*) base=$a ;;
	esac
	bsrc=named snap=$b kind=commit ssrc=range
elif [ -z "$head" ]; then
	# No commits yet: every file is part of the change.
	base=$empty bsrc=empty-tree
	[ -n "$want" ] && target=$want tsrc=named
else
	if [ -n "$want" ]; then
		target=$want tsrc=named
		for rr in $(git remote); do
			case $want in "$rr"/?*)
				tremote=$rr
				fetch_branch "${want#"$rr"/}"
				break
				;;
			esac
		done
		if [ -z "$tremote" ]; then
			if [ -n "$remote" ] && commit_of "refs/remotes/$remote/$want" >/dev/null; then
				tremote=$remote
				fetch_branch "$want"
			elif tcommit=$(commit_of "refs/heads/$want") || tcommit=$(commit_of "$want"); then
				:
			elif [ -n "$remote" ] && git check-ref-format --branch "$want" >/dev/null 2>&1; then
				tremote=$remote
				fetch_branch "$want"
			fi
		fi
		[ -n "$tcommit" ] || die "the target $want isn't a branch, tag or commit here${remote:+, or on $remote}"
	elif [ -n "$remote" ]; then
		tb=
		if s=$(git symbolic-ref -q --short "refs/remotes/$remote/HEAD" 2>/dev/null) && [ "${s#"$remote"/}" != "$s" ]; then
			tb=${s#"$remote"/} tsrc=origin-head
		elif s=$(net 20 git ls-remote --symref "$remote" HEAD 2>/dev/null) &&
			tb=$(printf '%s\n' "$s" | sed -n "s|^ref: refs/heads/\\(.*\\)${tab}HEAD\$|\\1|p" | head -n 1) && [ -n "$tb" ]; then
			tsrc='remote-head'
		elif command -v gh >/dev/null 2>&1 && tb=$(net 20 gh repo view --json defaultBranchRef --jq .defaultBranchRef.name 2>/dev/null) && [ -n "$tb" ]; then
			tsrc=gh
		else
			tb=
		fi
		tremote=$remote
		# When the remote is a fork, the target is the upstream repository's
		# branch, from a remote that points there or else from its URL.
		slug=$(slug_of "$(git config "remote.$remote.url")")
		if [ -n "$slug" ] && command -v gh >/dev/null 2>&1; then
			if f=$(net 20 gh api "repos/$slug" --jq 'if .fork then [.parent.full_name, .parent.default_branch, .parent.clone_url] | join(" ") else "" end' 2>/dev/null); then
				if [ -n "$f" ]; then
					# shellcheck disable=SC2086 # the three fields hold no spaces
					set -- $f
					tb=$2 tsrc=gh
					tremote=$(remote_for "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')") || tremote=$3
					note "$remote is a fork of $1, so the target is $1's $2"
				fi
			else
				note "gh couldn't say whether $remote is a fork, so the target is $remote's own default branch"
			fi
		fi
		if [ -n "$tb" ]; then
			target=$tb
			fetch_branch "$tb"
			if [ -z "$tcommit" ] && [ "$tremote" != "$remote" ]; then
				tremote=$remote
				note "the upstream repository's $tb couldn't be fetched, so the target is $remote's copy"
				tcommit=$(commit_of "refs/remotes/$remote/$tb") || tcommit=
			fi
			[ -n "$tcommit" ] || note "no copy of $tb from $tremote is here"
		else
			tsrc=none
			note "no target branch found: $remote names no default branch here, on the remote or through gh; name one to compare against"
		fi
	else
		note "no remote and no target named, so there is no target branch; name a local branch to compare against"
	fi
	if [ -n "$tcommit" ]; then
		if base=$(git merge-base "$tcommit" "$head" 2>/dev/null) && hex "$base"; then
			bsrc=merge-base
		else
			base=
			if [ "$shallow" = yes ]; then
				note "the repository is shallow, so the merge base with $target couldn't be determined; deepening it (git fetch --unshallow) needs the user's permission"
			else
				note "$target and HEAD have no merge base"
			fi
		fi
	fi
	if [ -z "$base" ]; then
		base=$head bsrc=head
	fi
fi
[ -n "$head" ] || note "the repository has no commits yet, so every file is part of the change"

# Whether the checked-out branch is the user's own work, asked only when git
# config runs code on the working tree: commits since the base by another
# author, an upstream that is a pull request ref, or a remote that is a URL
# make it someone else's unless the user said otherwise.
others=
if [ "$filters" = other ] && [ -z "$own" ] && [ -n "$head" ]; then
	if [ -n "$branch" ]; then
		m=$(git config "branch.$branch.merge" 2>/dev/null)
		case $m in refs/pull/*) others="its upstream is $m, a pull request" ;; esac
		r=$(git config "branch.$branch.remote" 2>/dev/null) && [ "$r" != . ] && ! git config "remote.$r.url" >/dev/null 2>&1 &&
			others="its remote is $r, a URL rather than one of this repository's remotes"
	fi
	if [ -z "$others" ]; then
		ob=
		[ -n "$tcommit" ] && ob=$(git merge-base "$tcommit" "$head" 2>/dev/null)
		if [ -z "$ob" ]; then
			others="with no merge base, its commits' authors couldn't be checked"
		else
			me=$(git config user.email 2>/dev/null)
			k=$(git log --no-ext-diff --no-textconv --format=%ae "$ob..$head" | sort -u | grep -c -vixF -- "${me:-'no email'}")
			[ "$k" -gt 0 ] && others="$k author email$([ "$k" = 1 ] || echo s) on its commits since the base differ from git config user.email${me:+ ($me)}"
		fi
	fi
fi

# Step 2: the starting state and the snapshot.
if [ -n "$others" ]; then
	state='head'
	printf '%s\n' "$head" >"$dir/before.txt" || die "can't write $dir/before.txt"
else
	state=full
	record "$dir/before.txt" ||
		die "couldn't build the snapshot ($(head -c 300 "$dir/record.err")): work from git status and git diff alone"
	tree=$(tail -n 1 "$dir/before.txt")
	hex "$tree" || die "building the snapshot printed no tree: work from git status and git diff alone"
	sub=$(awk '$1 == "1" && $3 ~ /^S/ && (substr($3, 3, 1) == "M" || substr($3, 4, 1) == "U") { sub(/^([^ ]* ){8}/, ""); printf "%s ", $0 }' "$dir/before.txt")
	[ -n "$sub" ] && note "changes inside submodules aren't in the snapshot, only the commit each points to: ${sub% }"
fi
if [ -z "$ssrc" ]; then
	if [ "$state" = head ]; then
		snap=$head kind=commit ssrc=head
		refused="uncommitted work wasn't reviewed: git config sets $risky, which runs code when git reads changed files, and the checked-out branch isn't the user's own work ($others); the snapshot is HEAD. If the user says the branch is theirs, run this again with --own"
	else
		snap=$tree kind=tree ssrc=working-tree
	fi
	[ "$filters" = other ] && [ "$state" = full ] &&
		note "git config sets $risky, which ran while the snapshot was built${own:+, since the user said the branch is theirs}"
	# An empty change: review the last commit against its parent.
	if [ -n "$head" ] && [ "$base" = "$head" ] && { [ "$snap" = "$head" ] || [ "$snap" = "$(git rev-parse "$head^{tree}")" ]; }; then
		if p=$(commit_of "$head~1"); then
			base=$p bsrc=last-commit
			note "the change is empty, with no commits past its base and nothing uncommitted, so this reviews the last commit against its parent"
		elif [ "$shallow" = yes ]; then
			note "the change is empty, and the last commit's parent isn't in this shallow repository"
		else
			base=$empty bsrc=empty-tree
			note "the change is empty and the last commit has no parent, so every file is part of the change"
		fi
	fi
	[ "$bsrc" = head ] &&
		note "with no base, the change is compared with HEAD: only uncommitted and untracked work is in it, not the branch's commits"
elif [ "$state" = head ]; then
	note "git config sets $risky and the checked-out branch isn't the user's own work ($others), so $dir/before.txt records HEAD alone"
fi

files=$(git diff --no-ext-diff --no-textconv --name-only -z "$base" "$snap" -- 2>/dev/null | tr -cd '\000' | wc -c | tr -d ' ') ||
	die "git couldn't diff $base and $snap"

put repository "$top"
put head "${head:-none}"
put branch "${branch:-none}"
put target "${target:-none}"
put target_source "$tsrc"
put remote "${tremote:-none}"
put target_commit "${tcommit:-none}"
put refreshed "$refreshed"
put shallow "$shallow"
put filters "$filters"
put state "$state"
put state_file "$dir/before.txt"
put snapshot "$snap"
put snapshot_kind "$kind"
put snapshot_source "$ssrc"
put base "$base"
put base_source "$bsrc"
put pr "${pr:-none}"
put files_changed "$files"
out=$out$notes
[ -n "${refused:-}" ] && put refused "$refused"
printf '%s' "$out" >"$dir/scope.txt" || die "can't write $dir/scope.txt"
printf '%s' "$out"
