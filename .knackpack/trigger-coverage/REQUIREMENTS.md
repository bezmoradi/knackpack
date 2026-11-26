knackpack-requirements/1

# Requirements: a trigger case on both sides for every skill and agent Claude starts on its own

### Readiness
READY WITH ASSUMPTIONS: nothing blocks; whether and when the new cases run as evals is left open on purpose.

### Problem and outcome
Claude decides from a description alone when to start a knackpack skill or agent. `evals/trigger-gaps.txt` lists 22 of the 31 that Claude may start on its own which lack a realistic request that should start them (a `starts:` case), one that shouldn't (a `quiet:` case), or both. Without both, a description that stops working, or starts firing on the wrong requests, goes unnoticed, and the trigger gate has nothing to measure it with. Success: `scripts/check.sh` reports every one of the 31 covered and the gap list empty.

### Scope
- Must deliver now: new `trigger` eval cases covering the missing kind for each of the 22 components, the gap list emptied, and the release paperwork the repository requires for a change under `evals/`: a PATCH version bump, a `CHANGELOG.md` entry, and the README's counts and trigger-case section.
- Out of scope: running the new cases as evals (see Q-01); trigger-tagged `starts:` cases for the 14 reviewers whose only `starts:` cases are behaviour cases not tagged `trigger` (see the risk below); any change to a skill, an agent, a hook or a script.
- Preserve: every existing case and grader unchanged, holdout cases included.

### Requirements and acceptance criteria

#### REQ-04: Every skill and agent Claude may start on its own has a starts: and a quiet: case
Acceptance: Given the branch, when `sh scripts/check.sh` runs, then its trigger coverage line reports all 31 skills and agents Claude starts on its own covered and `evals/trigger-gaps.txt` listing none.
- Each new tag is backed by a `tool_used` grader on the Skill tool for a skill or the Agent tool for an agent, naming the component, with `max: 0` for quiet, as `scripts/check.sh` requires.
- Each case's prompt reads like a real request that shares a topic with the component but never names it, and nothing the agent can read says it is being tested.
- A quiet grader can fail: its case lists the tool the component would be started with (Agent or Skill).
- Each fixture script runs in an empty folder and builds the repository its prompt describes, with commands that work with both GNU and BSD tools.
- No existing case, grader or holdout changes.

#### PROP-06: Release paperwork for a change under evals/
Acceptance: Given the branch, when `sh scripts/check.sh` runs, then the version and changelog checks pass: `.claude-plugin/plugin.json` says 0.40.1, higher than `origin/main`'s 0.40.0, and the newest `CHANGELOG.md` heading is `## 0.40.1 (2026-11-26)` with an entry saying nothing changes in the plugin.
- The README states the suite's total of 258 cases and 35 `trigger` cases, describes each new boundary in its trigger-case section, says the new cases haven't run, and no longer says Orchestrate review has no eval cases.
- `docs/release-testing.md` covers 0.40.1 and says what its testing left out.

### Constraints and dependencies
- `.claude/CLAUDE.md` sets the case format and tags, the rule that `evals/trigger-gaps.txt` may only shrink, the versioning rules (PATCH for a change with no feature or interface change), and the changelog and README steps before publishing.
- Running the cases calls the model on the maintainer's account, so CI never runs them.
- The trigger gate (`scripts/trigger-gate.sh`) runs only cases tagged `trigger`, with the Edit grant.

### Decisions and assumptions
- The developer accepted this item as REQ-04 in the intent record ("yes"); PROP-06 is the repository's own publishing rule applied to it, proposed by Claude.
- One case may carry several tags, starting one component and keeping its neighbours quiet, so 20 cases cover the 22 components.
- The Orchestrate review case lists no Agent tool, so it checks that the skill is chosen without starting every reviewer and paying for a full review.
- Most quiet cases for reviewers are change requests in their field, since each reviewer's description says it runs only when the user asks for a review.

### Open questions and risks
- Q-01: Should the twenty new cases run as evals before merging, and with what spending cap? One pass is estimated at $5 to $15. Resolved by the developer naming a cap, or saying to merge unrun. Blocking: no
- Risk: the 14 reviewers whose only `starts:` cases aren't tagged `trigger` get only their quiet side measured by the trigger gate when their descriptions change.
- Risk: the Go, TypeScript and Python fixtures weren't compiled or type-checked, since no Go, `tsc` or Python is on the machine that wrote them.

### Handoff
- Reviewers: check REQ-04's criteria against the case folders and the check's output, and PROP-06's against the README, `CHANGELOG.md`, `docs/release-testing.md` and `plugin.json`. Only REQ-04 is agreed by the developer.
- Run the cases with `claude plugin eval . --tag trigger --scaffold --ablation none --allow-tools Edit`, capped with `--max-cost-usd`, once Q-01 is answered.
