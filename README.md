# Knackpack

A pack of Claude Code knacks: skills and agents.

## Table of Contents

- [Introduction](#introduction)
- [What's Inside](#whats-inside)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Usage](#usage)
- [Trust Boundary](#trust-boundary)
- [Cost and Models](#cost-and-models)
- [Limitations](#limitations)
- [Update](#update)
- [Local Development](#local-development)
- [Acknowledgments](#acknowledgments)
- [Author](#author)
- [License](#license)

## Introduction

Knackpack is a collection of [Claude Code](https://code.claude.com) skills and agents, packaged as a plugin so you can install the whole set in one go. A *knack* is a skill you've practiced until it's second nature, and each one here came out of real projects: pressure-testing requirements before anything gets built, keeping track of what you and Claude actually agreed as requirements shift during a conversation, planning the work in small verifiable steps, challenging designs against their real requirements, keeping the thread of a long task when the conversation gets compacted, handing finished work to another agent for review, explaining a change in plain English, reviewing UI and Go changes with the same rigor every time, trying to break any change before it ships, and checking security-sensitive changes against OWASP ASVS.

Claude Code's bundled `/code-review` and `/security-review` commands review a diff. Knackpack covers the steps around that review: settling requirements and a plan before any code exists, reviewing the architecture of a plan, adversarial review that proves each finding before reporting it and has its most serious findings checked independently, and a security gate built on a pinned release of OWASP ASVS with a requirement-by-requirement evidence matrix.

The repository is also a Claude Code plugin marketplace, so this GitHub repo is what Claude Code installs from.

## What's Inside

### Skills

Skills are commands you run yourself. Plugin skills are namespaced, so each one starts with `/knackpack:`. Challenge requirements and Plan implementation run only when you type their command. Checkpoint, Explain and Handoff also respond when you ask for them in plain words, such as "save where we are" before compacting. Track intent is the exception: knackpack's hooks turn it on at the start of every session, so you never need to run it.

| Skill | Command | What it does |
|-------|---------|--------------|
| Challenge requirements | `/knackpack:challenge-requirements [request]` | Before anything is built, pressure-tests a feature request, bug report, spec or proposed solution: finds gaps, conflicts and hidden assumptions, asks the few questions whose answers change what gets built, and writes testable acceptance criteria |
| Track intent | Automatic; `/knackpack:track-intent` only where hooks are blocked | Keeps a private record of what you and Claude agreed in each session: requirements in your own words, assumptions, open questions, ideas that weren't agreed, and what has been built. Reads every message against it, so a question doesn't become an instruction and a correction doesn't erase other requirements, and reloads it after compaction |
| Plan implementation | `/knackpack:plan-implementation [change]` | Turns agreed requirements into a plan grounded in your actual repository: small, ordered work packages, each with dependencies, verification and a definition of done, plus security, compatibility, rollout and recovery where they matter |
| Checkpoint | `/knackpack:checkpoint` | Before you compact a long conversation, writes the task's goal, progress, decisions, gotchas and next steps to `CHECKPOINT.md`, so the next context picks up exactly where you left off |
| Explain | `/knackpack:explain [more \| topic]` | Explains what was just built in plain English for a junior developer: two paragraphs by default, a longer walkthrough with `more`, or scoped to a topic you name |
| Handoff | `/knackpack:handoff [focus]` | Writes a self-contained `HANDOFF.md` for another coding agent acting as a principal code reviewer: what changed, why, how it was verified, the risks, and what to scrutinize |

### Agents

Agents are reviewers that Claude runs in their own context. All six are report-only: they never edit files or commit. They run only when you ask for them, except the adjudicator, which the adversarial, ASVS and architecture reviewers start to check their most serious findings. To keep an agent from running at all, add `Agent(knackpack:<name>)` to `permissions.deny` in your settings.

| Agent | What it reviews | Works best with |
|-------|-----------------|-----------------|
| `architecture-reviewer` | Designs, plans and implementations: service boundaries, coupling, data ownership, consistency, failure handling, evolution and operational fit, judged against the real requirements rather than fashionable patterns | The proposal or plan to review, such as `PLAN.md` from Plan implementation, and the requirements it must meet |
| `ui-code-reviewer` | Front-end changes: visual quality, user experience, accessibility (WCAG 2.2 AA), responsive layouts and front-end code health, testing a running preview in a browser | An already-running preview of your app and the [Playwright MCP server](https://github.com/microsoft/playwright-mcp), added under the name `playwright`; without them it reviews the code only |
| `go-code-reviewer` | Go backend changes: security and authorization first, then architecture, then the code itself — correctness, concurrency, error handling, observability and performance | The Go toolchain, plus `staticcheck`, `golangci-lint` and `govulncheck` if you have them installed |
| `adversarial-reviewer` | Any change — code, configuration, infrastructure, migrations or CI — reviewed by an independent skeptic that tries to break it, proves each finding before reporting it, and grades evidence and severity separately | The project's own tests and tools, and the [GitHub CLI](https://cli.github.com) for reviewing pull requests |
| `asvs-security-reviewer` | Security-sensitive changes, checked against [OWASP ASVS 5.0.0](https://github.com/OWASP/ASVS/releases/tag/v5.0.0_release): plans security requirements before coding, reviews changes, and verifies security fixes, ending with a release recommendation backed by a requirement-by-requirement evidence matrix | Network access to download the ASVS release files, [jq](https://jqlang.org) to query them, and your project's security scanners |
| `adjudicator` | One claim about a change, usually another reviewer's Critical, High or blocking finding, checked from the evidence alone, without the reasoning behind it | The claim, the revision it's about and the files involved; you can also ask it to check a single finding yourself |

### Hooks

Knackpack's hooks all run one small shell script, `hooks/track-intent.sh`, for Track intent:

- At the start of each session you're attending, after compaction and when you resume a conversation, it loads the rules and the current session's record.
- With each message you send, it adds a short reminder to update the record before acting, and to offer the glossary when you define a project term, with the open questions and proposals.
- After each file edit and at the end of each turn, it checks for a missed update. If a turn edited files but not the record, the next message says so; if Claude wrote "Noted:" without updating the record, it has to fix that before the turn ends.

They skip headless `claude -p` runs. To turn them off, set `KNACKPACK_INTENT=off` (see [Track intent](#track-intent)).

## Prerequisites

- **[Claude Code](https://code.claude.com)** 2.1.292 or later, installed and signed in (tested with 2.1.310). Earlier versions miss fixes the pack relies on: 2.1.271 added the setting that lets reviewers start without your instruction files loaded, 2.1.289 made `claude plugin validate` check a plugin that sits next to a marketplace manifest, as this one does, and 2.1.292 stopped a compaction summary from letting Claude run the slash-command-only skills on its own.
- **macOS, Linux or WSL.** The reviewers' commands and the hooks assume a POSIX shell with git and tar.
- **[Playwright MCP server](https://github.com/microsoft/playwright-mcp)** (optional): lets `ui-code-reviewer` open your app in a real browser. Add it under the name `playwright`, because the reviewer only gets browser tools from a server with that name, and give it an output folder outside your repositories:

```text
$ claude mcp add playwright -- npx @playwright/mcp@latest --output-dir ~/.cache/playwright-mcp
```

Without `--output-dir`, the server writes page snapshots, console logs and screenshots into a `.playwright-mcp` folder in your project.

- **[Go](https://go.dev/dl)** (optional): `go-code-reviewer` builds, tests and vets the code it reviews. It also runs [staticcheck](https://staticcheck.dev), [golangci-lint](https://golangci-lint.run) and [govulncheck](https://pkg.go.dev/golang.org/x/vuln/cmd/govulncheck) when they're installed.

## Installation

Inside a Claude Code session, add this repository as a marketplace and install the plugin from it:

```text
/plugin marketplace add bezmoradi/knackpack
/plugin install knackpack@knackpack
```

Or do both with one command:

```text
/plugin install knackpack --marketplace bezmoradi/knackpack
```

You can do the same from your terminal:

```text
$ claude plugin marketplace add bezmoradi/knackpack
$ claude plugin install knackpack@knackpack
```

To make sure it's installed correctly, run the following command; its component inventory should list six skills, six agents and four hooks:

```text
$ claude plugin details knackpack
```

## Usage

### Challenge requirements

Run it before planning or coding. Pass the request as the argument, or run it right after you've described the request. Pass a long spec as a file path rather than pasting it:

```text
/knackpack:challenge-requirements Add Redis caching to the product catalog
```

It reads the relevant code and docs first, then asks one to three questions at a time, and only questions whose answers change what gets built. It finishes with a brief that contains:

- whether the work is ready to plan
- the requirements, with testable acceptance criteria (REQ-01, REQ-02, …)
- the decisions that are still open

For a substantial change, it also saves the brief as `REQUIREMENTS.md`, outside your repository, and gives you a line to start planning from it, in the same session or a new one:

```text
/knackpack:plan-implementation Plan from the brief at <path>/REQUIREMENTS.md
```

### Track intent

There's nothing to run. At the start of every session you're attending, knackpack's session-start hook loads a set of rules, and from then on Claude reads each of your messages against what you've agreed so far:

- A question, a suggestion ("maybe Redis would help") or a what-if ("what if support could see every organization someday?") doesn't change the agreement or start any work.
- A correction changes exactly what it names and keeps every other requirement.
- A bare "yes" approves the one proposal it answers. With several pending, Claude asks which.
- Claude asks only when a misreading would matter: who can see or change what, data ownership, actions that can't be undone, compatibility, or a big change in scope. Otherwise the conversation stays as it was, apart from a one-line "Noted: …" when the agreement changes.

Claude keeps the agreement in a Markdown record that separates what you asked for, in your own words, from what it assumed, what's still open, ideas that weren't agreed, and what has been built. It updates the record before doing the work a message approves, and knackpack's hooks remind it with every message and check every turn for a missed update, so the record doesn't rely on Claude remembering alone. After "Users can only see their own orders", "Managers should see everything, though" (Claude asks: within their organization, or across all of them?), "Only their organization" and "What if support could see all organizations someday?", the record reads:

```markdown
## Agreed
- REQ-01: Users can only see their own orders. Said: "Users can only see their own orders."
- REQ-02: Managers see every order in their own organization, not other organizations. Said: "Only their organization."
## Not agreed
- WHATIF-01: Support staff might someday see orders across all organizations. No change.
```

Each session gets its own record, so a new session starts with a clean slate and yesterday's feature can't leak into today's. The record reloads by itself after compaction and when you resume the conversation with `claude --continue`, `--resume` or `/resume`. To pick up earlier work in a new session, or to check or stop tracking, say so in plain words:

```text
Continue the order visibility work.
What have we agreed so far?
Don't track this session.
```

- **Where records live:** outside your repositories, one file per session in `~/.local/state/knackpack/intent/<repository>-<id>/`, or under `$XDG_STATE_HOME` if you set it. Records nobody has changed for 30 days are deleted. Claude copies a record into your repository only when you ask.
- **Glossaries:** when you confirm what a term means for the whole project, such as "customer means the paying organization", Claude offers to save it to a glossary, never to its own memory. If the repository has a team glossary, `.claude/rules/glossary.md`, the term goes there as an uncommitted change you review and commit, and Claude Code loads that file in every session for every contributor. Otherwise it goes to your personal glossary for that repository, which loads in every session you start there. Ask Claude to start a team glossary and it creates the file.
- **Plans and reviews:** when you ask for a plan or a review, Claude passes the record along as the requirements and marks which entries you confirmed.
- **Turning it off:** add `"KNACKPACK_INTENT": "off"` to the `env` block of `~/.claude/settings.json`, or of a repository's `.claude/settings.local.json` for just that repository. It's off in headless `claude -p` runs unless you set `KNACKPACK_INTENT=on`. Where an organization blocks plugin hooks, run `/knackpack:track-intent` at the start of a session instead.

### Plan implementation

Run it once the requirements are clear. In the session where you ran Challenge requirements, it picks up the brief on its own; in a new session, pass the brief's path, as in the line above:

```text
/knackpack:plan-implementation
```

It reads the relevant code before proposing anything, then breaks the work into packages (PLAN-01, PLAN-02, …). Each package lists what it changes, what it depends on, how it will be verified and when it's done. The plan also includes:

- a table mapping each requirement to the package and check that cover it
- the first step you can start on

Ask for planning only and it stays read-only. Ask it to go ahead and it implements the plan, updating each package's status from real test results. For a substantial change, it also saves the plan as `PLAN.md`, outside your repository, and gives you its path.

### Checkpoint

Run `/knackpack:checkpoint` when a conversation has grown long and you're about to compact it. It writes `CHECKPOINT.md` and gives you one line to paste as your first message after compacting:

```text
Read <path>/CHECKPOINT.md in full, then continue the task.
```

### Explain

```text
/knackpack:explain                    # two paragraphs on the most recent change
/knackpack:explain more               # a longer, detailed walkthrough
/knackpack:explain the retry logic    # two paragraphs on one topic
```

### Handoff

Run `/knackpack:handoff` when you want another coding agent to review what you just built. Add a focus if the conversation covered more than one change, such as `/knackpack:handoff rate-limit fix`; the file is then named after the focus, so it doesn't replace an earlier handoff. It writes `HANDOFF.md` and gives you the line to hand to the reviewer:

```text
Read <path>/HANDOFF.md in full, then carry out the review it describes.
```

`CHECKPOINT.md`, `HANDOFF.md`, `REQUIREMENTS.md` and `PLAN.md` go to the session's scratchpad folder when Claude Code provides one, and otherwise to a private `claude-<session-id>` folder in your temporary directory — never into your repository. That folder belongs to one session, and your operating system may clear it after a few days, so copy anything you want to keep.

### Reviewers

Ask for a reviewer by name:

```text
Use the knackpack:architecture-reviewer agent to review the plan at <path>/PLAN.md.
Use the knackpack:ui-code-reviewer agent to review my changes.
Use the knackpack:go-code-reviewer agent to review my changes.
Use the knackpack:adversarial-reviewer agent to review pull request 42.
Use the knackpack:asvs-security-reviewer agent to review my changes at ASVS Level 2.
Use the knackpack:adjudicator agent to check this finding: <the claim>.
```

Unless you name a target, a reviewer covers everything on your branch that its target branch doesn't have yet, plus uncommitted and untracked work. Every reviewer follows the same protocol:

- It records the exact state of your work as a git snapshot, without committing anything or touching your files, and checks at the end that it left everything as it found it.
- It reads your project's `CLAUDE.md` and rule files itself, so it follows your conventions instead of flagging them. If the change edits those files, it takes its guidance from the previous version, so a change can't exempt itself from review.
- It runs experiments, such as a reproduction or a regression test, only in a throwaway copy of the snapshot, and only when it's safe to run the change's code (see [Trust Boundary](#trust-boundary)).

The UI and Go reviewers work through a checklist and label findings by severity, from **[Blocker]** down to **[Nitpick]**. The adversarial reviewer works differently:

- It reports only findings it has proven, graded **Critical**, **High**, **Medium** or **Low**, and lists unproven concerns separately as open risks, each with the severity it would have if confirmed.
- It hands each Critical or High finding to the adjudicator for an independent check before reporting it.
- When you give it requirements with IDs, it reports each one as verified, violated or not verified.

A clean review is a valid outcome, so don't expect it to find something every time.

The architecture reviewer uses the same safeguards:

- It reviews proposals and plans as well as code.
- It ends with **PROCEED**, **PROCEED WITH CONDITIONS**, **REVISE BEFORE IMPLEMENTATION OR RELEASE**, or **INSUFFICIENT EVIDENCE**, which is also its answer when it can't read the plan it was asked to review.
- It can endorse a design as it stands.
- For an important decision, it drafts an architecture decision record for you to save rather than writing one itself.

The ASVS security reviewer works the same way and adds a security standard:

- It has three modes. **Plan** sets out security requirements and tests before you code, **review** checks a change, and **verify-fix** confirms that a security fix closes the hole and its bypasses.
- It downloads the official OWASP ASVS 5.0.0 requirements and the standard's cryptography appendix, and checks their checksums before using them, so it never works from memory or from a later draft of the standard.
- A review ends with the first of three recommendations that applies: **BLOCKED**, **READY FOR REQUIRED HUMAN REVIEW**, or **NO BLOCKING SECURITY ISSUES FOUND IN SCOPE**. A plan ends with whether it's ready to build.
- Missing security documentation is reported as a gap, and blocks only when your policy requires that document.
- It never claims ASVS compliance or certification. OWASP doesn't certify anything either.

## Trust Boundary

- **Reviewers can't edit files, but they can run commands.** They have no file-editing tools, and their instructions forbid commits, pushes and other changes to your repository. Each one still has a shell, the adversarial, ASVS and architecture reviewers can also fetch web pages, search the web and start the adjudicator, and the UI reviewer can drive a browser. "Report-only" rests on those instructions and the missing tools; it isn't a sandbox. No reviewer gets your other MCP servers or your skills, and the UI reviewer doesn't get the Playwright server's upload and run-code tools.
- **Your permission mode decides what runs without asking.** Plugin agents can't set their own permission mode, so they run in yours. In Manual mode you approve each command; in acceptEdits mode common file commands such as `rm`, `mv`, `cp` and `sed` run inside your project without asking; in auto mode a classifier approves actions for you.
- **Experiments run in a throwaway copy** made with `git archive`, which runs no git hooks and shares no branches, config or stashes with your repository. A copy protects your files, not your credentials.
- **Reviewers decide whether to run the code.** Your uncommitted work and local branches count as yours; pull requests, forks and other people's branches don't, unless you vouch for them. A reviewer runs untrusted code only if you tell it the environment is isolated and holds no credentials; otherwise it reviews statically and says what it didn't run. To be explicit, say so when you ask: "Review pull request 42 from an outside contributor; don't run its code."
- **For code you don't trust, isolate Claude Code itself** in a container or virtual machine, or turn on the sandbox (`/sandbox`) with `allowUnsandboxedCommands: false`, `failIfUnavailable: true` and read denies for your credential files. The sandbox covers shell commands only: MCP servers, including the browser, run outside it, and sandboxed commands still see your environment variables.
- **These guarantees assume reviewers run as ordinary subagents.** Started as an [agent team](https://code.claude.com/docs/en/agent-teams) teammate, a reviewer loads your `CLAUDE.md` files, and in split-pane mode it ignores its tool denials.
- **Skills run in your conversation with your normal permissions.** Their own files (checkpoints, handoffs, requirement briefs and plans) go to a private temporary folder, and intent records and personal glossaries to a private folder in your home directory. The only file Track intent writes in your repository is a team glossary, when you have one or ask for one, and it never commits.
- **The hooks run a shell script at session start, with each message, after each file edit and at the end of each turn.** `hooks/track-intent.sh` reads the session details Claude Code passes it and runs `git rev-parse` to identify the repository. It keeps its own folder under `~/.local/state/knackpack/intent`, holding the records, glossaries and one small file per session that notes which files the current turn edited, and deletes files there that nobody has changed for 30 days and empty folders nobody has touched for a day. It prints the rules, reminders and current record for Claude to read, uses no network, and never touches your repository. Claude writes the records itself, with its normal file tools and under your permission mode.

## Cost and Models

The adversarial, architecture, ASVS and Go reviewers and the adjudicator run on Opus, and the UI reviewer runs on Sonnet. A review reads a lot of code, so it costs more than a quick diff review: in testing on small changes, a single reviewer run cost between about $0.30 and $2.80 at API prices.

Track intent adds about 2,500 tokens of rules at the start of each session and after each compaction, plus the current record when it reloads, and a reminder of about 100 tokens with each message. Prompt caching makes repeat reads cheap.

To run a reviewer on a cheaper model, say so when you ask: "Use the knackpack:go-code-reviewer agent on Sonnet to review my changes." Setting `CLAUDE_CODE_SUBAGENT_MODEL` alone doesn't override a model an agent sets for itself; set `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` as well to put every subagent on one model.

## Limitations

- The reviewers are careful prompts, not proofs. They can miss defects, and a clean review isn't a guarantee. No evaluation suite has yet measured them against a baseline without the plugin.
- Headless runs (`claude -p`) deny any command that would need approval unless you allow it, so a review there may fall back to reading the code; its report says what didn't run.
- Reports live in the conversation. Save the ones you want to keep: Claude Code deletes old transcripts after `cleanupPeriodDays`, 30 days by default.
- Track intent's hooks make a missed update much less likely, but Claude still decides what counts as an agreement, so it can misread a message, and the record holds only what it wrote down. The end-of-turn check sees edits made with Claude's file tools, not changes made through shell commands. The record is evidence, not permission, so deploying, pushing or deleting data still needs your go-ahead in the conversation.
- Records live outside your project, so in acceptEdits mode Claude asks before each update. Auto mode sends those writes to its classifier instead.
- The hooks tell attended sessions from headless ones by two variables Claude Code sets for hooks but doesn't document. If a later version drops both, the hooks also run under `claude -p` until you set `KNACKPACK_INTENT=off`.
- Organizations that set `allowManagedHooksOnly` block plugin hooks, so Track intent doesn't start on its own there.

## Update

When a new version is released, refresh the marketplace and update the plugin from your terminal:

```text
$ claude plugin marketplace update knackpack
$ claude plugin update knackpack@knackpack
```

The new version loads in your next session, or right away if you run `/reload-plugins`.

## Local Development

The repository layout:

```text
knackpack/
├── .claude-plugin/
│   ├── marketplace.json   # makes the repo installable as a marketplace
│   └── plugin.json        # the plugin's name, version and metadata
├── agents/                # one Markdown file per agent
├── hooks/                 # the session-start hook that loads Track intent
└── skills/                # one folder per skill, each with a SKILL.md
```

The marketplace installs the repository root as the plugin, so everything at the root ships to every user. The hooks run at every session start, message, file edit and turn end for everyone who installs the plugin, so keep them fast, quiet and limited to their own folder, and don't add `.mcp.json`, `bin/`, `settings.json` or more hooks unless you mean every user to get them.

To see what the session-start hook prints without starting a session, feed it an event by hand:

```text
$ printf '{"session_id":"test","source":"startup"}' | sh knackpack/hooks/track-intent.sh rules
```

To try your changes without installing anything, start Claude Code with the plugin loaded from your clone:

```text
$ git clone https://github.com/bezmoradi/knackpack.git
$ claude --plugin-dir ./knackpack
```

All six agent files end with the same "Review protocol" section. After editing it in one, copy it to the others, then check that this prints the same checksum six times:

```text
$ for f in knackpack/agents/*.md; do sed -n '/^## Review protocol$/,$p' "$f" | shasum -a 256; done
```

Before committing, validate the plugin:

```text
$ claude plugin validate ./knackpack
```

Validation doesn't catch a misspelled frontmatter key such as `omitClaudeMD`, and Claude Code silently ignores a key it doesn't recognize. To check, on Claude Code 2.1.296 or later, start a session with `claude --debug --plugin-dir ./knackpack` and search its debug log in `~/.claude/debug/` for `does not recognize or apply`.

Installed copies only update when `version` in `.claude-plugin/plugin.json` changes, so bump it whenever you publish changes.

## Acknowledgments

The UI reviewer's overall structure, testing the live app first and then working through screen sizes, accessibility and code health with four severity levels, was inspired by the design-review agent in [OneRedOak/claude-code-workflows](https://github.com/OneRedOak/claude-code-workflows/tree/main/design-review).

## Author

This project is maintained by [Bez Moradi](https://github.com/bezmoradi)

## License

Knackpack is licensed under [MIT](https://github.com/bezmoradi/knackpack/blob/main/LICENSE)
