#!/bin/sh
# SessionStart hook: print knackpack's rules for challenging the developer
# instead of agreeing with them, so they hold in every conversation, not only
# when the challenge-requirements skill runs. Claude Code adds what it prints
# to the session's context at startup, resume, /clear and compaction.
#
# It reads nothing but the environment, writes nothing, uses no network, and
# exits 0 on every failure so a problem here never blocks a session.
#
# KNACKPACK_CHALLENGE=off turns it off. KNACKPACK_CHALLENGE=on also runs it in
# sessions nobody attends, such as `claude -p`, which it skips by default so
# headless runs and evals get no extra rules. Turned off, it prints one line
# telling Claude not to start challenge-requirements on its own: plugin skills
# ignore the skillOverrides setting, so this is the only switch for the skill
# short of disabling knackpack. `claude plugin eval` passes a case only
# variables named EVAL_*, so EVAL_KNACKPACK_CHALLENGE stands in for it there,
# letting an eval run the real hook headless.

umask 077
trap 'exit 0' EXIT

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
