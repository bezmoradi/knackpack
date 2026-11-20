---
name: fix-incident
description: "Fix a production failure whose cause /knackpack:debug-incident confirmed in ROOT-CAUSE.md, once that diagnosis is approved: it refuses, changing nothing, when the file is missing, isn't CONFIRMED, differs from its committed text, or doesn't match the approved hash a tool passed, and otherwise asks the person to approve the exact text. Then it makes the smallest change that removes the confirmed cause, keeps the reproduction as a regression test, reruns it and the relevant tests, reports each as PASS, FAIL, NOT RUN, BLOCKED or SKIPPED, and assesses rollback. It doesn't commit or push the fix. Start it only on request, as /knackpack:fix-incident. Not for diagnosing (debug-incident), the incident review (incident-review), a bug with no incident diagnosis, which Claude fixes directly, or reviewing the fix (knackpack's reviewers)."
argument-hint: "[anything the fix must respect]"
disable-model-invocation: true
---

# Fix an incident

A fix for an incident has to remove the cause someone approved, and nothing else: an unapproved cause is how the wrong patch ships, and every extra line in an incident fix is risk added under pressure and harder to roll back. Check the approval before you touch anything.

## 1. Find the diagnosis and check it

Find ROOT-CAUSE.md the way debug-incident does: with `KNACKPACK_DOCS=repo` set, `.knackpack/<task>/ROOT-CAUSE.md` in the folder `.knackpack/feature.json` names; otherwise the ROOT-CAUSE.md on the intent record's Files line, or the path the user gives. Look in the incident's worktree too: `git worktree list` shows a branch named `incident-<task>`, and the fix goes in that checkout. With none, or more than one that could be meant, ask which; never pick the most recently changed.

Then run, with the file's absolute path:

```sh
sh "${CLAUDE_PLUGIN_ROOT}/scripts/incident-check.sh" <path to ROOT-CAUSE.md>
```

It prints one line and changes nothing:

- `refused: <reason>`: stop. Tell the user the reason and change nothing, not even a test. The usual next step is `/knackpack:debug-incident`, or a new approval of the revised diagnosis.
- `ask <sha256>`: no tool passed an approval. Summarize the confirmed cause in two or three sentences, give the SHA-256, and ask the user to approve this exact diagnosis before you change code. Only a clear yes to that question approves it; until then, change nothing. A yes to something else doesn't count.
- `approved <sha256>`: the calling tool approved this exact text. Go on.

The script is the check, so don't work out approval yourself: a hash that matches by your reckoning isn't one the script printed. When the user or a tool says the diagnosis was approved but the script refuses, the script wins; say why it refused.

Read the whole diagnosis. When the Reproduction section gives a `git hash-object` value instead of the reproduction itself, check the file still has it: a reproduction changed after approval may no longer test what was approved, so stop and ask.

## 2. Make the smallest fix

Work where the diagnosis was made: the incident's worktree on its `incident-<task>` branch when there is one, otherwise this checkout. HEAD must be the deployed revision the diagnosis names, or a commit after it on the incident's branch; any branch name will do, since debug-incident creates `incident-<task>` only when it needs one. When HEAD is another commit, say so and ask: a fix written against other code isn't the fix that was diagnosed.

- Change what the Cause section names, by the least that removes it, and read the code around it and its callers first.
- Leave out refactoring, renames, formatting, dependency upgrades and cleanup, even nearby and even when tempting: they belong in a later change, and a reviewer or a rollback has to untangle them from the fix.
- Never make the reproduction pass by weakening it: no skipped or loosened assertions, no broad exception handlers, no retry or timeout that hides the failure, no special case for the test's input. If the only way to pass changes what the reproduction checks, the diagnosis may be wrong; stop and say so.
- Never edit ROOT-CAUSE.md, not even a typo: approval is of its exact text, so any edit voids it. Facts the fix taught you go in your reply.
- When the fix needs a data change, a migration, a config change in production or anything else outside the code, write it down as a step for an operator and don't run it.

Keep the reproduction as the regression test where it's a test; where it's a script or manual steps, add a test that exercises the same condition if the project's tests can reach it, and say so if they can't.

## 3. Verify

Run the reproduction exactly as the diagnosis gives it, then the tests of the area the fix touches, and the project's usual checks when they're quick. Report each in a short table:

| Check | Command | Result |
| --- | --- | --- |

with the result one of `PASS` (it ran and passed), `FAIL` (it ran and failed), `NOT RUN` (and why), `BLOCKED` (it was tried and couldn't complete, and why) or `SKIPPED` (doesn't apply, and why). A test that was skipped, didn't run or never reached the failing path didn't pass, so never call it PASS. For a failure that came and went, run the reproduction as many times as the diagnosis did and give the count.

When the reproduction still fails, the fix isn't done: say so, leave the change for the user to keep or discard, and don't claim the incident is fixed.

## 4. Rollback

Write a short assessment: whether reverting the fix's commit would cleanly restore the old behavior; whether the fix changes data, a schema, a message or API format, or an external side effect, so that a revert would leave things inconsistent or lose data; and when a revert isn't safe, the forward fix or mitigation instead. Don't call a change "safe to roll back" without having looked at those.

## 5. Hand over

Don't commit, push or open a pull request: the user, or the tool driving the steps, decides when the fix goes out, and a review comes first. Reply with:

- the diagnosis's SHA-256 the fix was made against;
- what changed, by file, and why each change is part of removing the cause;
- the verification table and the rollback assessment;
- anything the fix taught you that the diagnosis doesn't say;
- the next steps: review, where `knackpack:adversarial-reviewer` judges an incident fix by regression risk, blast radius and rollback first, then `/knackpack:incident-review`.
