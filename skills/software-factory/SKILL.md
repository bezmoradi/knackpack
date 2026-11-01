---
name: software-factory
description: Turn knackpack's software factory page on or off, open it, check its status or clear it. The page, software-factory.html in knackpack's state folder, lists every Claude Code session on this machine with its state (working, waiting for permission or a reply, your turn, failed, ended), the questions Claude asked in dialogs and the answers picked, its intent record, which agents ran and how they ended, with knackpack reviewers' verdicts and reports, and its tasks, and reloads itself every 5 seconds from files knackpack's hooks write. Nothing is recorded until it's turned on. Run only when the user types the command.
argument-hint: "[on | off | open | status | clear]"
disable-model-invocation: true
---

# Software factory

Knackpack's hooks keep `software-factory.html` up to date while tracking is on. This skill only switches tracking and opens the page; it never edits the page or the recorded files itself, since the hook owns their format.

Run the hook script with the action the user asked for, from `$ARGUMENTS`, defaulting to `open`:

- `on`: `sh "${CLAUDE_PLUGIN_ROOT}/hooks/factory.sh" on`, then open the page as below.
- `off`, `status` or `clear`: `sh "${CLAUDE_PLUGIN_ROOT}/hooks/factory.sh" <action>`. Ask before `clear`, since it deletes every recorded session and can't be undone.
- `open`: `sh "${CLAUDE_PLUGIN_ROOT}/hooks/factory.sh" status`. If it says tracking is off, say so and offer `/knackpack:software-factory on`, because the page would show nothing new. Then open the page it names.

To open the page, use `open <page>` on macOS, `xdg-open <page>` on Linux, or `wslview <page>` under WSL, whichever exists. If none works, or the session runs where no browser can reach this machine's files, give the user the page's absolute path to open themselves.

Reply in two or three lines: whether tracking is on, the page's path, and, after turning it on, that sessions appear from their next event, so sessions already open show up once they next do something. Give the script's message verbatim if it reports an error.

What the page records, so you can answer questions about it: event times, each session's working folder, notification and error types, subagent types, task subjects, the questions Claude asked in question dialogs with the answers picked, and the report path and verdict line knackpack's reviewers end with; never prompts, tool input, file contents or any other message. It also shows the session's intent record, read from track-intent's files when the page is built. Files untouched for 7 days are deleted when a session starts. `KNACKPACK_FACTORY=off` stops recording even when tracking is on, and sessions run headless with `claude -p` aren't recorded unless `KNACKPACK_FACTORY=on`.
