# PRD: What knackpack takes from the Agent Skills specification

Status: partly built in knackpack 0.17.0, for [issue #19](https://github.com/bezmoradi/knackpack/issues/19). It combines two independent analyses written on 2026-10-31 against knackpack 0.16.0 (commit `b1557f8`) and Claude Code 2.1.316: this one, and a second coding agent's handoff. The same release adds five PostgreSQL checks to the database reviewer, with seven eval cases, three PRD rules to Write docs, with two, a rule in Orchestrate review and three eval-command options, a React reviewer with six eval cases, and review rules for finding the same defect elsewhere, probing a running local app, new values reaching code the change didn't touch, code that behaves differently under test, test runs that didn't run what they claim, implementations that must agree, and caches that skip checks, each from a separate review of another project's skill. A later review of the whole of one of those projects led to fixes in knackpack itself: the eval judge model is pinned and suspected first, a check stops agents naming a file one fixture writes, a failing test counts against a change only if it passes on the base, and the adjudicator's fix check reruns a case that must still work. It also added rules on tests that can't fail for the reason they name, response headers, committed developer tooling, local previews that reach production, vetting a performance number, changelogs, renames and planning, with four eval cases. Two field reports on intent tracking led to hook and skill fixes: shell edits to the project count toward the missed-update check, scratch files in temporary folders don't, misplaced entries, long Status lines and credentials are flagged, credentials are hidden in what the hooks print, and "Noted:" is kept for changes the developer didn't spell out. The OpenTelemetry skill became a report-only reviewer agent. The README's Acknowledgments credit every source except the two behind the review rules, which the developer asked not to credit. That work is outside this PRD.

knackpack's skills already meet the [Agent Skills specification](https://agentskills.io/specification)'s required rules. What was missing was any check that they keep doing so, and evidence that their descriptions start the right skill. This release adds:

- **A format check in `scripts/check.sh`** (R-01). `claude plugin validate` checks almost none of the format, so this check covers names, description and compatibility lengths, and one-line frontmatter.
- **Six trigger cases** (R-02) at the boundaries where the wrong skill changes scope or cost. They're written and their fixtures checked. One has run: the duration-flag case passed once on 2026-10-31, for $0.15.
- **A Claude Code-only statement in the README** (R-03), and a README command that lists graders passing or failing in both arms (R-07).
- **Rules in `.claude/CLAUDE.md`** (R-08), labeled by whether the format requires them, its documentation advises them, or knackpack chose them.

Deferred: splitting skills into files loaded on demand (R-04, after experiment E-1), and repeated holdout runs (R-06). Dropped: `license` and `compatibility` in each skill (R-05, R-09).

## How the two analyses compare

Both analyses reached the same main conclusions:

- knackpack stays a Claude Code plugin and keeps `argument-hint` and `disable-model-invocation`.
- The format's limits belong in `scripts/check.sh`, not a second gate or a test framework.
- Trigger evidence should use knackpack's own eval runner, not the documentation's JSON layout.
- Nothing gets split into files read on demand before a test shows those reads work.
- No skill or agent changes its name, tools, report location or invocation policy.

What the second analysis changed in this one:

- **Three kinds of rule.** Every rule says whether the format requires it, its documentation recommends it, or knackpack chose it. `.claude/CLAUDE.md` now says so.
- **Check what validation already catches first.** That led to experiment E-0 below, which showed the format check has to live entirely in `scripts/check.sh`.
- **Duplicate keys and how values are read.** The shell's line readers aren't a YAML parser. Instead of adding one as a dependency, knackpack now requires one-line frontmatter values, which the shell reads exactly as YAML does, and rejects a key that appears twice.
- **R-05 dropped.** `plan-implementation` is 18,996 characters, so the 13 characters of `license: MIT` would take it past the 19,000-character cap. The plugin's `LICENSE` already covers every skill.
- **Fewer trigger cases, aimed better.** Not 42 cases for every component, but six where a wrong start changes scope or cost, and no positive case for Orchestrate review, whose run costs as much as every reviewer.
- **Skills Claude mustn't start on its own** aren't judged by trigger cases.
- **Safety checks that pass in both arms** stay, read apart from the graders that measure what knackpack adds.
- **Two corrections.** The longest description is 856 characters, not 858: the earlier count included its quotes. Character counts aren't token counts.

Where this analysis kept its position against the second one:

- **No separate guideline file.** The second analysis proposed `docs/agent-skills-guidelines.md`. The developer asked for the guidelines in `.claude/CLAUDE.md`, which Claude Code loads into every session on the project, so a contributor's agent can't miss them, while a docs file has to be found and read. One file also keeps a single source of rules, which the second analysis's own acceptance criteria ask for.
- **No trigger cases for skills started by command or hook.** Hooks don't run in evals (README, Limitations), and whether a case's prompt can run a slash command is unverified.
- **Additions the second analysis didn't cover:** the grader audit (R-07), Claude Code's 25,000-token budget across re-attached skills after compaction, and running trigger cases with `--ablation none`.

## Problem

Claude Code's skills follow the Agent Skills open standard and extend it ([Claude Code skills docs](https://code.claude.com/docs/en/skills)). knackpack had never been checked against it, so it didn't know where it departs from the format, whether its descriptions start the right skill, or which of the documentation's practices would improve its skills and evals. This affects contributors, who decide what a skill says and how it's tested, and users, who need a skill to start when it should.

## Scope

In scope: the specification and its documentation on writing skills, descriptions, evaluation, scripts and client support, compared with `skills/`, `agents/`, `evals/`, `scripts/check.sh`, the README and `.claude/CLAUDE.md`.

Not in scope:

- Support for products other than Claude Code.
- A loader, registry or adapter for other products.
- Changes to what any skill or agent says, the tools it gets, or when it starts.
- Copying text from agentskills.io: knackpack writes everything itself.

## How knackpack compares

Each claim carries one evidence label. Documented: stated by the source. Observed: seen in the repository or by running a command. Inferred: reasoned from evidence, not shown directly.

| Specification point | knackpack | Evidence |
| --- | --- | --- |
| `name`: 1 to 64 lowercase letters, digits and hyphens, no leading, trailing or doubled hyphen, matching the folder | All 11 skills conform. The format's prose says "unicode" while listing `a-z` and `0-9`, so knackpack's ASCII-only names are its own policy. | Observed, Documented |
| `description`: 1 to 1,024 characters | 368 to 856 characters. Claude Code's listing cap is 1,536 per skill, so the format's limit is the binding one. | Observed, Documented |
| Keys outside the format | 10 skills use `argument-hint` and 3 use `disable-model-invocation`. The reference validator ([`validator.py`](https://github.com/agentskills/agentskills/blob/f130f348f502d9804278a617f86929846896d2e9/skills-ref/src/skills_ref/validator.py) at `f130f34`) reports any key outside its six as an error. Claude Code's docs say claude.ai uploads and the Skills API fail on them. | Observed, Documented |
| Body under 500 lines and about 5,000 tokens (advice) | The largest bodies are under 490 lines. `scripts/check.sh` caps each `SKILL.md` at 19,000 characters, which is a character count, not a measured token count. | Observed |
| `scripts/`, `references/`, `assets/` loaded on demand (advice) | None. Whether Claude Code lets a plugin skill read its own folder without a prompt is unresolved (E-1). | Observed |
| Catalog cost | The 8 model-invocable skill descriptions total 5,340 characters, and the 13 agent descriptions, which the format doesn't cover, total 22,207. Claude Code warns when subagent descriptions pass 15,000 tokens ([sub-agents docs](https://code.claude.com/docs/en/sub-agents)). | Observed, Documented |
| Trigger tests with near misses (advice) | Before this release: positive trigger graders for 2 of the 8 model-invocable skills, and 3 cases checking that no agent starts. | Observed |
| Output evals with a baseline, repeated runs, time and tokens (advice) | `claude plugin eval` runs a no-plugin arm and records cost, duration and turns. 81 of 97 cases set `runs: 1`. | Observed |

## Experiment E-0: what validation already catches

On 2026-10-31, `claude plugin validate` (Claude Code 2.1.316) ran on 13 scratch plugins, each with one broken skill. It warned only when the description was missing. It passed every other case: an uppercase name, a name that doesn't match its folder, a doubled or leading hyphen, a 1,100-character description, an empty description, a key written twice, a 600-character `compatibility`, an unknown key, an unquoted `: ` inside a value, and a folded description. Observed.

## Requirements

### R-01. `scripts/check.sh` checks the format. Built

For each `skills/*/SKILL.md`, the check covers:

- **`name`:** 1 to 64 lowercase ASCII letters, digits and single hyphens between them, matching the folder.
- **`description`:** 1 to 1,024 characters, counted without quotes.
- **`compatibility`, when present:** 1 to 500 characters.
- **Frontmatter (knackpack policy):** one `key: value` per line, no key twice. A value is double-quoted without escapes, single-quoted, or plain and free of anything YAML would read differently.

The existing key check now separates the format's six keys from Claude Code's, and still fails on any key that's on neither list.

Acceptance: `sh scripts/check.sh` prints `ok Agent Skills format: names, descriptions and one-line frontmatter` for the current skills. On a scratch copy of the repository, the check must fail, naming the file and the field, for each of these defects in one skill: an uppercase name, a name that doesn't match its folder, a doubled hyphen, a missing name, a 1,025-character description, an empty description, a key written twice, a 501-character `compatibility`, an unquoted `: `, a folded description, and an escaped quote. It must pass with a description of exactly 1,024 characters and with one in double quotes. Results are under [Verification](#verification).

### R-02. Six trigger cases. Written; one run once

Each case is tagged `trigger` and runs with `--ablation none`: without the plugin, no knackpack skill can start, and a single arm also scores the `with-only` graders.

| Case | Request | Must happen |
| --- | --- | --- |
| `trigger-research-open-choice` | Move sessions to Redis, or something simpler? | Research starts. The answer names the missing index or the write on every request. |
| `trigger-research-settled-choice` | The decision is made: make the timeout flag a duration | Research doesn't start. `main.go` uses a duration flag with a 30-second default. |
| `trigger-write-docs-runbook` | Bring the restore runbook in line with the Makefile | Write docs starts. The runbook gives `make restore` with `BACKUP_ID` and `CONFIRM=yes`. |
| `trigger-issues-close-duplicate` | Close issue 42 as a duplicate of 17 | Create issues doesn't start, and the reply doesn't claim the issue was closed. |
| `trigger-otel-vendor-choice` | Grafana Cloud or Datadog for dashboards? | The OpenTelemetry reviewer doesn't start, and the reply answers the vendor question. |
| `trigger-go-review-not-orchestrate` | Review my change to `handlers.go` | Orchestrate review doesn't start. The Go reviewer's run is reported but not required. |

Acceptance: every fixture builds in a scratch folder and shows its premise (done). Then the six pass in one run of `claude plugin eval . --tag trigger --scaffold --ablation none`, which is still to run (D-3).

Deferred: trigger cases for `checkpoint`, `explain` and `handoff`, and routing cases between agents, such as an interface question that belongs to the design pattern reviewer rather than the slop reviewer.

### R-03. The README says knackpack works only in Claude Code. Built

A Limitations bullet names what ties the skills to Claude Code: the two keys, `${CLAUDE_SESSION_ID}` in their save folders, and knackpack's agents and hooks. It also says a copied skill folder hasn't been tested in another product.

### R-04. Supporting files loaded on demand. Deferred until E-1

If a plugin skill can read its own files without a prompt, in default mode and headless, the platform notes in `create-issues` could become one file per platform. Those notes are 4,595 characters, and a run uses one platform of four.

### R-05. `license` in each skill. Dropped

`plan-implementation` would pass the 19,000-character cap, and the plugin's license already covers every skill.

### R-06. Holdout confirmations run 3 times. Deferred

`.claude/CLAUDE.md` already says not to trust one run. Whether to pay three times for each holdout run is the maintainer's call.

### R-07. Grader audit. Built

The README gives a `jq` command that lists, for a two-arm run, the scored graders that passed in both arms and those that failed in both.

Acceptance: the command reads both `aggregate-result.json` and the file `--json` writes. On the 0.16.0 results it listed 128 graders passing in both arms and 2 failing in both: `issues-draft-only-no-publish`'s `no-invention` and `tf-for-each-removal-kept`'s `no-shift-claim`. Many of the 128 are guards, such as the `-kept` cases, and the rest show where the suite doesn't separate knackpack from Claude alone.

### R-08. `.claude/CLAUDE.md` rules. Built

- **The format rule:** one bullet under Rules naming the three kinds of rule and why the Claude Code keys stay.
- **The compaction budget:** the 25,000-token budget across re-attached skills.
- **Writing and improving skills and agents:**
  - Test skills that start only by command or hook through that path.
  - Write a correction from a run as a concrete fact at the step where the mistake happens.
  - Ask of each instruction whether the model would get the task wrong without it, and count a cut that loses a mode boundary, an evidence requirement or a save location as a regression.
  - Keep safety guards that pass in both arms.
  - Run trigger cases with `--ablation none`.

### R-09. `compatibility` in each skill. Dropped

The README states the limit once, which saves characters in skills near their cap.

## Not recommended

- **The `metadata` field:** `plugin.json` already holds the version and author.
- **The `allowed-tools` field:** it's experimental in the format. In Claude Code its grant lasts one turn and isn't gated by workspace trust, and no skill has a measured need for it.
- **Bundled scripts:** they raise the same permission question as E-1, and nothing yet shows one would help.
- **Shorter agent descriptions:** 6,096 characters of relay instructions repeat across the agents, but the only text the main session always sees is the hook's output, which `scripts/check.sh`'s worst case puts at 9,770 of its 9,900 bytes.
- **skill-creator's description loop:** its `evals.json` format isn't interchangeable with `claude plugin eval`'s.
- **Making descriptions start their skill more readily:** knackpack's agents start only on request by design.
- **The reference validator in `scripts/check.sh`:** it rejects the Claude Code keys knackpack keeps, and stripping them to get a clean result would hide what ships.

## Experiments still open

- **E-1. Supporting files.** In a scratch plugin, a skill reads `${CLAUDE_SKILL_DIR}/references/probe.md`. Run it interactively in default mode and with `claude -p`, and record whether the read was allowed, prompted or denied.
- **E-2. Cheap trigger cases.** Claude Code's eval docs say hitting `max_turns` counts as a run error, so the trigger cases use the usual generous limits. Measure their real cost on the first run. The first, one run of the duration-flag case, cost $0.15 and took 20 seconds.
- **E-3. The reference validator.** In a scratch copy of `skills/`, run `uvx --from "git+https://github.com/agentskills/agentskills@f130f348f502d9804278a617f86929846896d2e9#subdirectory=skills-ref" skills-ref validate <copy>/<skill>`. The expected result, Inferred from its source, is that `checkpoint` passes and the other 10 fail on the Claude Code keys. This session's sandbox refused to run the downloaded code.

## Open decisions

- **D-2. Where this PRD lives once merged.** The repository root ships to every user who installs knackpack.
- **D-3. Running the trigger cases.** One run of the six with `--ablation none`. The 0.16.0 suite averaged about $0.33 a run, so this is a few dollars, an estimate rather than a measurement.

## Verification

Run on 2026-10-31, on the branch moved onto main at `633893a`:

- **The full checks:** `sh scripts/check.sh` and `dash scripts/check.sh` pass every check: validation, keys, README counts, the 103 eval cases, the Agent Skills format, skill sizes, and version 0.16.2 above main's 0.16.1. ShellCheck, actionlint, zizmor, codespell, markdownlint-cli2 and lychee aren't installed on this machine, so CI's Linux job is the first to run them on these changes.
- **R-01 against broken copies.** On scratch copies of the repository, one defect at a time in `skills/explain/SKILL.md`:
  - Each of these failed with the file, the field and the reason: an uppercase name, a name that doesn't match its folder, a doubled hyphen, a missing name, a 1,025-character description, an empty description, a key written twice, a 501-character `compatibility`, an unquoted `: `, a folded description, an escaped quote, and a plain value holding ` #`, which YAML would cut off at the `#`.
  - Each of these passed: a 1,024-character description, a double-quoted and a single-quoted value holding `: `, and the unchanged tree.
  - The first attempt at the double-quoted case wrapped a description that already held quotes. It failed, correctly, and was rerun with a clean value.
- **R-02 fixtures.** Each fixture ran in its own scratch folder:
  - The Python files compile, and the sessions table has no index.
  - Both Go modules build. The review case also passes `go vet` and leaves `handlers.go` uncommitted.
  - The runbook's old `make restore BACKUP=<id>` stops with the Makefile's message, and `BACKUP_ID=<id> CONFIRM=yes` runs.
  - The duplicate-issue case's remote is `github.invalid`.
  - Both regex graders were checked in Node against right and wrong answers.
- **R-07.** The audit command ran over every 0.16.0 result file.

## Sources

- Agent Skills: [overview](https://agentskills.io/home), [specification](https://agentskills.io/specification), [best practices](https://agentskills.io/skill-creation/best-practices), [optimizing descriptions](https://agentskills.io/skill-creation/optimizing-descriptions), [evaluating skills](https://agentskills.io/skill-creation/evaluating-skills), [using scripts](https://agentskills.io/skill-creation/using-scripts) and [adding skills support](https://agentskills.io/client-implementation/adding-skills-support).
- The reference validator, `skills-ref` 0.1.0 at `f130f34`, whose README says it's for demonstration only.
- Claude Code 2.1.316: [skills](https://code.claude.com/docs/en/skills), [sub-agents](https://code.claude.com/docs/en/sub-agents) and [plugin evals](https://code.claude.com/docs/en/plugin-evals).
- Anthropic's [skill-creator](https://github.com/anthropics/skills/tree/main/skills/skill-creator).
- The second analysis: a coding agent's handoff, given by the developer, reviewing the same commit.
