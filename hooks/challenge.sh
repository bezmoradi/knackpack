#!/bin/sh
# SessionStart hook: print knackpack's rules for challenging the developer
# instead of agreeing with them, so they hold in every conversation, not only
# when the challenge-requirements skill runs. Claude Code adds what it prints
# to the session's context at startup, resume, /clear and compaction.
#
# It reads nothing but the environment, apart from the repository's settings
# files with KNACKPACK_DOCS=repo (below), writes nothing, uses no network, and
# exits 0 on every failure so a problem here never blocks a session.
#
# KNACKPACK_CHALLENGE=off turns it off. KNACKPACK_CHALLENGE=on also runs it in
# sessions nobody attends, such as `claude -p`, which it skips by default so
# headless runs and evals get no extra rules. Turned off, it prints one line
# telling Claude not to start challenge-requirements on its own: plugin skills
# ignore the skillOverrides setting, so this is the only switch that stops
# Claude starting the skill on its own while leaving it available on request.
# A Skill(...) permission deny rule blocks a skill outright, though the docs
# don't say whether one covers a plugin's skills. `claude plugin eval` passes a
# case only variables named EVAL_*, so EVAL_KNACKPACK_CHALLENGE stands in for
# it there, letting an eval run the real hook headless.
#
# KNACKPACK_DOCS=repo, set by the developer or by a tool that runs the agent
# and reads the documents it commits, such as a push gate, makes it first print
# the rules for committing the requirements brief and the plan to the
# repository with scripts/commit-docs.sh, in every session, headless ones
# included, and whatever KNACKPACK_CHALLENGE says: the variable is the
# request, and those skills are too close to their size limit to carry the
# rules themselves. Without it, nothing about committing is printed. The
# variable can also come from the repository's own settings, which mustn't
# switch the mode on for someone who didn't choose it, so the hook first runs
# the script's read-only --check in the project folder, and when that refuses
# prints a short note instead of the rules, so Claude never writes a copy.

umask 077
trap 'exit 0' EXIT

why=
if [ "${KNACKPACK_DOCS:-}" = repo ]; then
	root=${CLAUDE_PLUGIN_ROOT:-}
	[ -n "$root" ] || root=$(cd "$(dirname -- "$0")/.." 2>/dev/null && pwd)
	why=$(cd -- "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null && sh "$root/scripts/commit-docs.sh" --check 2>/dev/null)
fi
if [ -n "$why" ]; then
	printf '%s\n\n' "# Committed documents are off

\`KNACKPACK_DOCS=repo\` is set, but knackpack won't commit the requirements brief or the plan in this repository: ${why#not committed: }. Save briefs and plans only where the skills say, and when you first save one, tell the developer in one sentence why it wasn't committed."
elif [ "${KNACKPACK_DOCS:-}" = repo ]; then
	cat <<'EOF'
# Committed documents

`KNACKPACK_DOCS=repo` is set: the developer or a tool that reads committed documents, such as a push gate, asked for knackpack's requirements brief and plan to be committed to the repository too. That is the request challenge-requirements and plan-implementation mean when they say not to write into the repository unless the user asks.

- **When challenge-requirements saves a brief or plan-implementation saves a plan**, save it where the skill says, then, if the session's folder is in a git repository, write a copy at the repository's top level, the folder `git rev-parse --show-toplevel` prints: `.knackpack/<task>/REQUIREMENTS.md` or `.knackpack/<task>/PLAN.md`, with `<task>` a name of at most 64 lowercase letters, digits and hyphens that starts with a letter or digit. A plan built from a brief in `.knackpack/` goes in that brief's folder, the one `.knackpack/feature.json` names; give any other task a new folder.
- **The copy names nothing outside the repository**, since it may be pushed to a public one: cite the brief by its repository path, and leave out paths from this machine, such as the intent record's, the scratch folder's and the home folder's. The scratch brief names the intent record, so write the copy without that line rather than copying the file. Like every brief, it holds no secrets.
EOF
	printf '%s\n' "- **Commit the copy with \`sh \"$root/scripts/commit-docs.sh\" <the copy's absolute path>\`.** It commits that file and \`.knackpack/feature.json\` alone, never other staged or unstaged work, and prints one line. Tell the developer what it printed: the document is committed only when the line starts with \`committed\` or \`already committed\`; when it starts with \`not committed\`, say why and give the scratch copy's path instead. When the line says the committed text differs from the file written, a commit hook or git filter changed it: what its \`git show\` command prints is the text that was committed, so that is the text to review."
	cat <<'EOF'
- **To revise a brief or plan**, write the copy again and run the script again: the change becomes a new commit, and the old text stays in history.
- **Wherever the skills give the brief's or plan's path**, for planning, review, `/knackpack:execute-plan` or a handoff, give the committed copy's absolute path.
- **Nothing else changes:** a brief challenge-requirements doesn't write, as when it stays short, isn't committed either, and neither is a research brief.

EOF
fi

off() {
	printf '%s\n' "The developer turned knackpack's challenge rules off, so don't start the challenge-requirements skill on your own; run it only when the developer asks for it."
	exit 0
}

setting=$(printf '%s' "${KNACKPACK_CHALLENGE:-${EVAL_KNACKPACK_CHALLENGE:-}}" | tr '[:upper:]' '[:lower:]')
case $setting in
off | 0 | false | no) off ;;
on | 1 | true | yes) ;;
*)
	# The same test as track-intent.sh: a background session started with
	# `claude --bg` (cli and 0) runs the hook, `claude -p` (sdk-cli and 0)
	# doesn't, and the attended flag decides only when the entry point is
	# the Agent SDK's or missing.
	case ${CLAUDE_CODE_ENTRYPOINT:-} in
	sdk-*) [ "${CLAUDE_CODE_SESSION_ATTENDED:-}" = 1 ] || exit 0 ;;
	'') [ "${CLAUDE_CODE_SESSION_ATTENDED:-}" = 0 ] && exit 0 ;;
	esac
	;;
esac

cat <<'EOF'
# Challenge, don't please

These rules from knackpack hold for the whole session. The developer would rather hear about a gap now than find it after the work is done, so read every request, plan and claim, theirs and your own, for what's missing or wrong.

- **Start the challenge-requirements skill before acting on any request to change something**, however small, and skip it only for a request that changes nothing. The developer asked for this on every change, because a change that looks too small to question is where an unstated assumption gets through; started that way, the skill stays short and then makes the change.
- **Look for gaps before you agree or act.** Ask what would make this fail: a missing case, a conflict with something already agreed or in the code, an unsafe default, a cheaper path. Raise each gap that would change what gets built or decided, with what shows it. When you find none, say so in a few words: a gap made up to look thorough costs the developer time to dismiss and buries the real ones.
- **Disagree when the evidence says so.** If the developer's claim, plan or code is wrong, say so plainly and why, even when they sound sure. Don't soften a real problem into praise, and don't drop a correct answer because they push back without new evidence; change it when they bring some.
- **Say "I don't know" when you don't, and name what would settle it**, such as a file, a document, a test or a question for the developer. A confident guess is the answer most likely to please and least likely to be caught.
- **Check before you hedge.** When you can find out yourself, by reading the code or the documentation or running a command you're allowed to run, do that instead of guessing or answering "I don't know".
- **Mark a guess as a guess where it would change the developer's decision.** Leave confidence labels off everything else, where they become noise.

These rules change how you answer, not what you're allowed to do. If the developer asks you to stop challenging them, stop for the rest of the session or until they ask again.
EOF
