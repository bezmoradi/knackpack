---
name: execute-plan
description: Carry out an existing implementation plan as its orchestrator. Start it before implementing anything from a plan, such as PLAN.md from knackpack's plan-implementation skill or a plan document with work packages, once the user says to build it ("go ahead with the plan", "implement PLAN-02", "the plan looks right, do it"), and when plan-implementation was asked to implement as well as plan, however small the change, since even a one-line package goes to an implementation subagent, not a direct edit. Claude stays the engineering owner, gives each subagent a bounded work package, runs independent packages in parallel in separate git worktrees, reads each actual diff and reruns its checks, starts the reviews the risk calls for, then integrates and verifies the whole. It starts several subagents, so it costs more tokens than editing directly. Not for writing or revising a plan (plan-implementation), a change with no plan, which Claude makes directly, or a review of finished work (knackpack's reviewers).
argument-hint: "[path to the plan, and which packages]"
---

# Plan Executor

## Mission

Turn an agreed plan into a verified, integrated change, as its orchestrator.

You own the engineering outcome: the user's intent, the plan, the
assignments, their order, the integration and the final acceptance.
Implementation subagents own the implementation: they investigate their
package, change code and tests, run the package's checks and review their own
work. Being responsible for the implementation doesn't mean writing it: a
parent that writes the code can no longer review it independently, and its
context fills with detail the rest of the run needs room for.

These rules hold for the whole run:

- **Delegate every implementation change, whatever its size.** Source code,
  tests, configuration, migrations and build files are changed by an
  implementation subagent, a one-line fix included. There is no size below
  which you edit directly: "it's only one line" is how an orchestrator turns
  back into the developer and stops checking the work.
- **Delegate by coherent package, not by line or file.** One implementer can
  own a one-line fix, or several tightly coupled packages; the number of
  agents follows the structure of the work, never a wish to delegate more.
- **A report is evidence, not proof.** Accept a package only after reading
  its actual diff and seeing its checks pass.
- **Edit the project yourself only under the exceptions in section 8**, and
  say which one each time.

Update the plan file's package status in place as work moves: it's the
record the user, a later session and other tools read. The exception is a
plan committed under `.knackpack/`, as with `KNACKPACK_DOCS=repo`: a person's
approval may be tied to its exact text, so never edit or commit it. When it
needs revising, stop and ask the user to revise it with
`/knackpack:plan-implementation`, which Claude can't start on its own.

Keep such a plan's package statuses instead in a file named `PLAN-status.md`, saved in the session scratchpad named in your system prompt, if there is one. Otherwise run `printenv TMPDIR` once (use `/tmp` if it prints nothing) and use the folder `claude-${CLAUDE_SESSION_ID}` inside it, writing the folder's full path literally in every later command. Create it with `mkdir -p -m 700 <folder>`, then check it with `[ -d <folder> ] && [ ! -L <folder> ] && [ -O <folder> ] && chmod 700 <folder>`; if the check fails, stop and tell the user.
The file isn't named `PLAN.md`
because plan-implementation keeps its own copy of the plan in that folder
under that name; if `PLAN-status.md` is already there for another task,
choose another name rather than overwrite it.

Write nothing into the repository beyond what the packages change.

## 1. Confirm the authorization and the plan

Execution needs the user's explicit go-ahead for this plan, such as "go
ahead", "implement it" or a request to plan and then implement. A request
for a plan, a question about one, or praise for its content without saying
to build it isn't one: confirm before starting, since each package changes
their repository. Once authorized, don't invent further approval steps, but
existing organizational or repository approvals still apply; name the
concrete one if it blocks dependent work.

The authorization covers implementing the packages the plan and the user
name. Committing, pushing, opening pull requests, deploying, migrating real
data and deleting anything outside the change each need their own go-ahead,
unless the user already gave it.

Read the plan passed with this skill, or the one plan-implementation just
saved, and the session's intent record if knackpack keeps one: it's newer
where they differ, and only its Agreed entries are confirmed. If the user
refers to a plan you can't find, ask for its path rather than rebuilding it
from memory. When only some packages are named, execute those and the ones
they depend on, and say so.

Record the baseline: `git rev-parse HEAD` and `git status --porcelain`.
Compare them with the baseline the plan states. If the code the plan builds
on has changed, or a package is blocked on an open decision, reassess the
affected packages before assigning them, and keep blocked work out of the
assignments.

If your environment has a task list, mirror the packages there.

## 2. Shape the assignments

Turn the plan's packages into assignments, one per implementer:

- Keep tightly coupled packages in one assignment, and keep a package whole:
  splitting one across agents makes them negotiate a contract that only the
  plan should set.
- Give each assignment explicit ownership: the files, modules or
  responsibilities it may change. Two assignments that run at the same time
  never own the same file. Shared files that collide easily, such as lock
  files, generated code, registries, routing tables and migration numbering,
  belong to one owner or to assignments that run one after another.
- Run dependent work in the plan's order. Run independent assignments in
  parallel only when the shared contract they build on is settled and
  committed or written into each prompt, they own separate files, and there's
  a defined point where you integrate and verify them together. Different
  files alone don't make work independent.
- Start no more implementers at once than there are ready, independent
  assignments, and fewer when you can't review results as fast as they
  arrive: an unreviewed result is unverified work.

## 3. Choose where each implementer works

- **One implementer at a time** works in the session's own working tree.
  Its changes land where you can inspect them, and nothing needs merging.
- **Implementers running in parallel** each get a separate working copy:
  start them with the Agent tool's `isolation: "worktree"`. In Claude Code, a
  worktree-isolated subagent starts from the repository's default branch
  unless the `worktree.baseRef` setting is `"head"`, and even then it sees
  only committed, tracked files, so uncommitted work in the session's tree,
  an earlier package's included, is invisible to it. Put the contract and
  any earlier changes it needs in its prompt, or ask the user before
  committing them. A worktree left unchanged is cleaned up automatically; one
  with changes is kept, and the agent's result names its path and branch.

Use Claude Code's `general-purpose` agent as the implementer, or an agent
the project defines for implementation work. Knackpack's own agents are
report-only reviewers and can't implement.

If you can't start subagents at all, because the Agent tool is missing or
denied, stop and tell the user: implementing directly is their call, not a
fallback to take silently.

## 4. Write each assignment as a contract

The implementer knows only what its prompt says, so every assignment states:

1. **Objective**: the outcome, and the plan's package IDs and requirement
   IDs it serves.
2. **Scope**: the behavior or components involved, and what is out of scope.
3. **Ownership**: the files and modules it may change. Anything else it
   finds it needs to change, it reports instead of changing.
4. **Context**: the relevant architecture, conventions, contracts, earlier
   packages' results, and the paths of the plan and intent record to read.
5. **Constraints**: what must not change, such as public contracts, security
   controls and compatibility; the repository's own rules, such as a project
   that forbids test code; and that it must not commit, push, start other
   agents, or loosen an assertion, threshold, timeout, snapshot or
   suppression to make a check pass.
6. **Acceptance criteria**: the package's completion criteria from the plan.
7. **Verification**: the exact commands or runs to perform, and what each
   should show.
8. **Reporting**: files changed, decisions it made and why, each check it
   ran with its command and result, its self-review of the diff, and anything
   unresolved or blocked.

Ask it to review its own diff against the acceptance criteria before it
reports, and to stop and report, rather than force a way through, when a
central assumption proves false, the work grows beyond its scope, or passing
a check would mean weakening it.

Write assignments that can't be read two ways: "clean up the handler" lets
an implementer decide the scope; "move the token check before the database
call in the order handler, keeping its error response" doesn't.

## 5. Coordinate while they work

Subagents started in the background notify you when they finish: don't
poll them, and don't do their work while you wait. Use the time to prepare
the next assignment or review a finished one.

When an implementer reports a blocker, a contract that has to change or
scope that grew, decide it from the plan and the agreement: answer it, adjust
the affected assignments, or stop the affected work and ask the user when the
decision is theirs. Never let an implementer settle a requirement on its own.

To send work back, continue the same agent with SendMessage when its context
helps, or start a fresh one with a corrected contract when its context would
repeat the mistake.

## 6. Verify every result yourself

For each finished assignment, before marking any package done:

- Read the actual change, with `git status --porcelain` and `git diff` in the
  tree it worked in, new files included, not the summary in its report.
- Check every changed file against its ownership. Investigate any change
  outside it: have the implementer revert it, or accept it with a reason.
- Check the change against the acceptance criteria and the plan's approach,
  and look for what reports leave out: a requirement only partly met, error
  paths, removed or loosened checks, placeholder code, and changes that
  don't fit the repository's conventions or architecture.
- Rerun the decisive checks yourself, or confirm from their output that they
  ran against this revision. A claim that a test passed, a test that never
  runs, or a check run before the last edit isn't evidence.
- Mark the package done in the plan only when its verification and
  completion criteria pass, naming the check that passed. Otherwise send it
  back with what failed.

## 7. Get independent review where the risk calls for it

An implementer's self-review and your diff review are enough for a small,
low-risk change. Get an independent review before accepting changes to
authorization, tenant isolation, sensitive data, money, migrations or other
irreversible effects, concurrency, public contracts, or code that is hard to
verify by running it.

Start the reviews the plan names for each package: approving the plan for
execution approved them. With knackpack installed, those are its reviewers,
such as `knackpack:adversarial-reviewer` for risky changes,
`knackpack:security-reviewer` for security-sensitive ones and the stack's own
code reviewer. If the risk calls for a review the plan didn't name, ask the
user before starting it, and continue other work meanwhile. Give each
reviewer the change, saying where it is: the worktree's path and the
package's commits, or the files the package changed in the integrated tree,
since a reviewer otherwise reviews whatever is uncommitted or unpushed where
it starts. Give it the requirements as the paths of the brief, the plan and
the intent record, not the implementer's account or your conclusions, so its
judgment stays independent.

Resolve every Critical or High finding before accepting the work: send the
fix to an implementer, or record the user's decision to accept the risk.
When reviewers contradict each other or a finding is disputed, weigh the
evidence each gives; for a Critical or High finding still in doubt, offer an
independent check by `knackpack:adjudicator`, as the reviewers' descriptions
say. Verify each fix as section 6 says.

## 8. Edit the project yourself only as an exception

You may change files the packages own only to:

- resolve a conflict while integrating results,
- make a small correction that the integration needs and no single
  assignment owns, such as an import two results both need,
- fix orchestration or tracking state, such as the plan's status, the task
  list or the intent record, or
- act where delegation is impossible or clearly counterproductive, with the
  user's agreement when that means implementing a package.

Keep each one as narrow as its reason. Before making it, say which exception
applies and why; afterwards, inspect the resulting diff, and list it in the
final report. A small feature or bug fix is never an exception: assign it,
however small. If you find yourself writing more than an integration needs,
stop and assign it.

## 9. Integrate and accept

Bring parallel results into the session's tree one at a time, in dependency
order. For a worktree, collect its change with
`git -C <worktree> add -A && git -C <worktree> diff --cached --binary <start>`,
where `<start>` is the commit it started from, check that it applies with
`git apply --check`, and then apply it. If it doesn't apply, that's an
integration conflict, for you to resolve under section 8 or to send back.
Verify after each integration, not only at the end, so a break points at one
result.

When the user has asked you to commit, commit each package once it's
accepted, a worktree's result once it's integrated and verified, before the
next is integrated, so each can be reviewed and reverted on its own. Commit
only the files its diff changed, by path: `git add -- <new files>` for the
files it created, since a commit by path takes only files git already
tracks, then `git commit -m <message> -- <paths>`, which leaves the user's
other staged work out. Leave out any file that had changes at the baseline,
since a commit by path takes the whole file, the user's lines included, and
say which you left out. Commit hooks run after you choose the files, and can
reject the commit or stage more:

- If a hook rejects it, unstage the new files (`git reset -q -- <new files>`)
  and treat what the hook reported as a failed check.
- Otherwise check what the commit holds
  (`git show --name-only --format= HEAD`). If it holds anything else, take it
  back with `git reset --soft HEAD~1` and then `git reset -q -- <paths>`,
  which leaves the user's work as it was, commit nothing more, since the hook
  would do the same again, and tell the user what the commit held.

Follow the repository's message style, never amend, skip hooks or push, and
note each commit beside its package's status.

When every assigned package is in:

- Run the plan's full verification on the integrated tree.
- Review the whole diff against the baseline for unintended changes,
  leftover debugging code and files nothing asked for.
- Check every requirement in the plan's coverage table against the evidence.
- Update the plan's statuses, and the intent record's Built entries if
  knackpack keeps one, from what passed.

Keep the plan honest throughout: record meaningful deviations, reassess
downstream packages when a contract changes, drop steps the approach no
longer needs, and don't hide scope growth inside a progress update.

## 10. Stop when the plan stops holding

Stop the affected work and reassess with the user when a central assumption
proves false, the change would weaken a security control, a migration risks
data loss, the work grows beyond the agreed scope, validation can't exercise
the behavior, or passing a check would mean loosening it. A failed check
normally calls for diagnosis and correction, not escalation. Continue
independent work that's still safe.

## 11. Report

End with:

- Completed, incomplete and blocked packages, kept apart, each with the check
  that decides it.
- The files changed, the integrated revision you verified, and any commits
  you made, with each file you left out of them and why.
- The checks you ran yourself, with their results; label anything only an
  implementer reported, and anything still to run in a later environment.
- The reviews run, their unresolved findings, and any risk the user accepted.
- For each review, the snapshot its report names, and the accepted changes
  made after it, such as fixes for its findings, which it didn't see.
- Each direct edit you made under section 8, with its reason.
- Worktrees left on disk, by path; remove them only when the user says so.
- What wasn't done and needs the user's go-ahead, such as committing,
  pushing or deploying.

Never report a planned or delegated check as passed. Completing the plan
isn't security approval or permission to release.
