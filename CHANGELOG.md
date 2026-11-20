# Changelog

Each knackpack release, newest first. Each one starts with a heading `## <version> (<date>)`, and an entry that breaks the public interface starts with **Breaking:** and says what users need to do. Installed copies of knackpack read this file at session start to tell their users what changed since their version, so keep its headings in that form. Entries before 0.37.0 are the titles of their release commits.

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
