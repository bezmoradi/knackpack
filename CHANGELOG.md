# Changelog

Each knackpack release, newest first. Each one starts with a heading `## <version> (<date>)`, and an entry that breaks the public interface starts with **Breaking:** and says what users need to do. Installed copies of knackpack read this file at session start to tell their users what changed since their version, so keep its headings in that form. Entries before 0.37.0 are the titles of their release commits.

## 0.40.0 (2026-11-21)

- Requirements briefs now have a format a program can check, `knackpack-requirements/1` (#98). Every brief Challenge requirements writes has the line `knackpack-requirements/1`, gives each requirement as a heading such as `#### REQ-01: <text>` followed by an `Acceptance:` line, and ends each open question's line with `Blocking: yes` or `Blocking: no`, or says `- None.` when there are none. Its short form, which writes no brief, is unchanged.
- Plan implementation checks a brief before planning from it. When a question blocks, it stops and names the blocking questions, and plans only once you've answered them or tell it to plan around them. When the brief breaks the format, such as a requirement with no `Acceptance:` line, it stops and names the problem and its line. A brief written before 0.40.0 is planned from as before, and Claude says it wasn't checked. Execute plan runs the same check when you hand it a brief instead of a plan.
- The check is `scripts/requirements-check.sh <file>`, which changes nothing and prints one line: `ready` (exit 0), `blocked` and the blocking questions' IDs (1), `invalid:` and the reason, with its line number (2), `none` for a brief in the older format (3), or `error:` and the reason when it's run wrongly or can't read the file (4). The format and these lines are new public interface, described in the README under "Reading knackpack from a tool" and in full in `docs/requirements-format.md`; nothing existing changes meaning.

## 0.39.1 (2026-11-20)

- Nothing changes in the plugin. For maintainers: the pre-push hook is one line that hands over to `scripts/prompt-audit.sh --hook`, which now runs the trigger gate itself after the audit passes, so a hook installed by any release runs every pre-push check without reinstalling. In a clone of this repository, the repository's own `.claude/settings.json` installs the hook at session start, or updates knackpack's older one, and leaves a pre-push hook that isn't knackpack's alone; a fork's clone gets nothing, since the hook spends on the account of whoever pushes.

## 0.39.0 (2026-11-20)

- At the end of a turn that edited a file other than a document (`.md`, `.mdx`, `.markdown`, `.rst`, `.adoc` or an intent record) after the last Bash or PowerShell command it ran, or that ran no command, Claude is sent back once to run your project's checks that cover those files, such as its tests, build, type check or linter, or to say why there are none (#95). It's on by default, in headless `claude -p` runs, CI and evals too, and with `KNACKPACK_INTENT=off`; in a headless run, a send-back costs one more model turn. It writes nothing. Set `KNACKPACK_TURN_CHECK=off` to turn it off, or `EVAL_KNACKPACK_TURN_CHECK=off` in an eval case.
- When a knackpack agent's reply is missing its last line, `knackpack-verdict/1: pass` or `knackpack-verdict/1: block`, or, from any agent but the adjudicator, the `knackpack-findings/1:` line before it, or either is malformed, a new hook sends the reply back to the agent once to fix them. Whenever it can't tell, the reply goes through as it is. It keeps one empty marker per agent it sent back in `~/.local/state/knackpack/reply-check` and deletes those untouched for 30 days. Set `KNACKPACK_REPLY_CHECK=off` to turn it off.
- Orchestrate review saves each reviewer's reply beside its report and checks the verdicts with `scripts/review-coverage.sh`: while any reviewer lacks a valid verdict line, it doesn't call the review complete.
- Every reviewer resolves the review's target, base and snapshot with `scripts/review-scope.sh`, so reviewers run together read the same snapshot against the same base. On a GitHub remote it asks `gh` once whether `origin` is a fork. A reviewer that can't run it follows the protocol's steps by hand, as before; in a headless run, allow reviewers Bash, as with `--allowedTools Bash`, since a narrower `Bash(sh:*)` wasn't enough in testing.
- With `KNACKPACK_DOCS=repo`, `scripts/commit-docs.sh` refuses a task document that holds a common secret shape, such as an authorization header's credential, a private-key block, or a GitHub, AWS, Slack, Stripe live or Anthropic key, and takes back a commit whose hooks or filters added one. It names each kind and line, never the value. It matches only those shapes, so it can't prove a document clean.
- Execute plan records each failed attempt at a package beside the package's status, in the plan file or, for a committed plan, `PLAN-status.md`: its approach, the failing check and its first error line. A repeat that fails the same way isn't a new attempt. After 2 failed attempts, or the number the plan sets, it starts fresh with an agent that only diagnoses, and if that fails too, it stops the package and asks you. It never undoes your own uncommitted work without asking.
- Handoff groups a large change's files into review slices in dependency order, each marked a behavior or a structure change, with where they meet. It never rewrites history to match them.
- Six instructions in Challenge requirements, Execute plan and Research now say what to do instead of what not to do; their behavior isn't meant to change.
- For maintainers: `evals/consistency.sh` and the `consistency` eval cases measure how consistent repeated runs are, `scripts/check.sh` requires trigger cases for every skill and agent Claude may start that `evals/trigger-gaps.txt` doesn't list, and the prompt audit's pre-push hook also runs `scripts/trigger-gate.sh` on changed descriptions. Reinstall the hook with `sh scripts/prompt-audit.sh --install`.

## 0.38.1 (2026-11-20)

- `/knackpack:debug-incident`'s description no longer promises ranked hypotheses. Its root-cause step lists every hypothesis and rules each out with evidence, and it never ranked them. What the command does is unchanged.

## 0.38.0 (2026-11-20)

- Three commands for a production incident, so a fix never starts before its cause is shown (#89). `/knackpack:debug-incident` does one step per run, triage, then a reproduction at the deployed revision that fails, then ranked hypotheses and a test that tells them apart, and saves each to `ROOT-CAUSE.md`, whose Status ends `CONFIRMED`, `UNCONFIRMED` or `BLOCKED`. It changes no code, keeps secrets and personal data from your logs out of what it writes, and works in a separate git worktree on an `incident-<task>` branch when your checkout isn't the deployed revision or has uncommitted work. `/knackpack:fix-incident` refuses unless the diagnosis is `CONFIRMED` and approved, by you in the session or by a tool that passes the approved file's SHA-256 in `KNACKPACK_INCIDENT_APPROVED_SHA256`, then makes the smallest fix, reruns the reproduction and assesses rollback, without committing. `/knackpack:incident-review` writes a blameless `INCIDENT.md`. None of them starts on its own.
- With `KNACKPACK_DOCS=repo`, `.knackpack/<task>/ROOT-CAUSE.md` and `.knackpack/<task>/INCIDENT.md` are committed the way briefs and plans are, one commit per revision. Their paths, headings and Status words, and the approval variable, are new public interface; nothing existing changed.
- The adversarial and slop reviewers judge an incident fix, a change that adds or changes a `ROOT-CAUSE.md` or that you say fixes an incident, by whether it removes the cause, its regression risk, blast radius and rollback first, and report anything beyond the cause.
- A reviewer that can't run commands now writes its `knackpack-coverage/1` and `knackpack-finding/1` lines itself, in the same form the count command prints, where before it left them out. With a shell nothing changes. A program reading replies may now get those lines from such a reviewer, so it should check each one and drop one that's malformed, as it already should.

## 0.37.1 (2026-11-20)

- The README and `.claude/CLAUDE.md` say that `main` also requires the `Claude review` check, as the ruleset now does (#90). Nothing in the plugin changes.

## 0.37.0 (2026-11-20)

- At the start of each session, knackpack tells you when a newer version is out, gives the commands to update, and Claude opens its first reply with a summary of what changed since your version. It checks this file on GitHub with one request, waiting at most 3 seconds and showing nothing when it can't connect. `KNACKPACK_UPDATE_CHECK=off` turns it off, and so do Claude Code's own `DISABLE_UPDATES`, `DISABLE_AUTOUPDATER` and `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` (#87).
- This changelog.

## 0.36.0 (2026-11-20)

- A code-health reviewer that assesses a code base and compares it with an earlier revision (#86).

## 0.35.0 (2026-11-17)

- Reviewers check claims themselves and report each requirement's coverage (#84).

## 0.34.0 (2026-11-17)

- An opt-in gate before /compact, one question per llm grader, and every open issue closed (#82).

## 0.33.1 (2026-11-17)

- Grade the findings and verdict lines a push gate reads (#81).

## 0.33.0 (2026-11-16)

- Keep the agreed way of working in front of Claude after compaction (#78).

## 0.32.2 (2026-11-15)

- Tell the user to keep a copy of the plan (#76).

## 0.32.1 (2026-11-15)

- Name the glob characters reviewers must quote (#72).

## 0.32.0 (2026-11-15)

- A reviewer catalog and one machine line per finding (#71).

## 0.31.0 (2026-11-15)

- Intent hook notices that say how to fix, hand-back turns that keep their baseline, and a checkpoint reply that says to wait (#70).

## 0.30.0 (2026-11-14)

- Plan builds go straight to Execute plan (#69).

## 0.29.2 (2026-11-14)

- Globs through find, and the four-line reply whatever the brief asks (#68).

## 0.29.1 (2026-11-14)

- Reviewers start no agent but the adjudicator (#67).

## 0.29.0 (2026-11-14)

- Separators that survive zsh, macOS head -0, and plan work handed to Execute plan (#66).

## 0.28.1 (2026-11-14)

- Recognise subagent hand-backs as the hook receives them (#63).

## 0.28.0 (2026-11-14)

- Fixes from a field report on 0.25.0 and 0.26.0 (#61).

## 0.27.0 (2026-11-13)

- Prompt audit before a push, and every audit finding resolved (#58).

## 0.26.0 (2026-11-13)

- Findings line, committed documents, compaction focus (#56).

## 0.25.0 (2026-11-12)

- Execute-plan orchestrates implementation through subagents (#50).

## 0.24.0 (2026-11-08)

- End every reviewer's reply with a machine-readable verdict line (#49).

## 0.23.1 (2026-11-07)

- Run the hooks in background sessions (#47).

## 0.23.0 (2026-11-05)

- TypeScript specialist (#44).

## 0.22.0 (2026-11-05)

- CSS and Web Components specialists, and Go reviewer traps (#42).

## 0.21.0 (2026-11-05)

- Remove Software Factory, keeping the skills, agents and three hooks (#40).

## 0.20.1 (2026-11-02)

- Software Factory: push gate, execution path and a scroll area beside the conversation (#36).

## 0.20.0 (2026-11-02)

- Software Factory: tabs, status bar, terminal-style tool rows, and the pasted-image fix (#33).

## 0.19.1 (2026-11-01)

- Software Factory: themes, text size, image paste and the terminal's permission choices (#31).

## 0.19.0 (2026-11-01)

- Software factory plugin and factory page fixes (#29).

## 0.18.0 (2026-11-01)

- Challenge rules, context warning and the software factory page (#26).

## 0.17.0 (2026-10-31)

- Skill-writing rules, React and OpenTelemetry reviewers, review rules from outside skills, and track-intent fixes (#24).

## 0.16.2 (2026-10-31)

- CLAUDE.md: keep the README banner's last line in step with the merge gate (#21).

## 0.16.1 (2026-10-31)

- README: restore the banner's Merged badge, with a true approval line (#23).

## 0.16.0 (2026-10-31)

- Docker, Kubernetes, Terraform and database reviewers, and OpenTelemetry and Create issues skills (#18).

## 0.15.0 (2026-10-30)

- Fixes from three field reports: reviewers' report files, orchestrate-review and intent tracking (#16).

## 0.14.0 (2026-10-30)

- Fixes from knackpack's review of itself and its field reports, and Claude's review blocks on every problem (#14).

## 0.13.3 (2026-10-30)

- The merge gate binds everyone, and Claude reviews Dependabot's pull requests (#11).

## 0.13.2 (2026-10-30)

- Follow-ups from Claude's review of #7, and the linter install on Ubuntu 26.04 (#9).

## 0.13.1 (2026-10-30)

- Pull requests merge only after Claude approves, with linters and pinned updates in CI (#7).

## 0.13.0 (2026-10-30)

- Intent tracking without false missed-update messages from subagents, queued messages and other kinds of record (#4).

## 0.12.0 (2026-10-30)

- Orchestrate review runs every reviewer together, and fixes from an adversarial review of the code base.

## 0.11.0 (2026-10-30)

- A security reviewer with OWASP coverage beyond ASVS, a Python code reviewer, and intent-tracking fixes.

## 0.10.0 (2026-10-30)

- A slop reviewer reports what a change adds without a reason, and the Go reviewer grades dead code by evidence.

## 0.9.0 (2026-10-29)

- The Go reviewer checks naming and package layout, and reviewers name their report files.

## 0.8.1 (2026-10-29)

- A design pattern reviewer, intent tracking without false nags, and stricter pre-publish checks.

## 0.7.1 (2026-10-29)

- Intent tracking sees every record update and keeps its "Noted:" lines.

## 0.7.0 (2026-10-29)

- Reviews passed on in full, safer handling of checked-out pull requests, and saved files that carry over.

## 0.6.0 (2026-10-28)

- Reviewers flag steering attempts, fewer false alarms, and a behavior eval suite.

## 0.5.1 (2026-10-28)

- Reviewers keep git's diff programs off for blame and log too.

## 0.5.0 (2026-10-28)

- Safer reviews and intent tracking, one severity scale, and an assess mode.

## 0.4.0 (2026-10-27)

- Reviewers save their report to a file and reply with its path.

## 0.3.3 (2026-10-27)

- Show wrapped assumptions in full in the intent reminder.

## 0.3.2 (2026-10-27)

- Remind Claude of its unconfirmed assumptions with every message.

## 0.3.1 (2026-10-26)

- Have the handoff's reviewer write its review to a file.

## 0.3.0 (2026-10-25)

- Add write-docs and research skills.

## 0.2.2 (2026-10-24)

- Replace a changed glossary meaning instead of adding a second entry.

## 0.2.1 (2026-10-24)

- Fix intent tracking's glossary handling and folder cleanup.

## 0.2.0 (2026-10-24)

- Add track-intent, which keeps a running record of what was agreed.

## 0.1.0 (2026-10-24)

- Add knackpack: five Claude Code skills and six report-only review agents.
