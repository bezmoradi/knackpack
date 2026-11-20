---
name: incident-review
description: "Write the incident review for a production failure that /knackpack:debug-incident diagnosed and /knackpack:fix-incident fixed, as INCIDENT.md beside its ROOT-CAUSE.md: summary, impact, timeline, the cause and contributing factors, the fix, what was verified, rollback, follow-ups and open questions. It works from the diagnosis, the fix's diff and a fresh run of the reproduction, keeps verified facts apart from estimates, marks the review a draft while verification is incomplete, and describes systems and decisions, never a person to blame. Start it only on request, as /knackpack:incident-review. Not for diagnosing or fixing (debug-incident and fix-incident), an incident review with no knackpack diagnosis to start from, or other documents (write-docs)."
argument-hint: "[anything the review must include]"
disable-model-invocation: true
---

# Write the incident review

An incident review is for the people who will run, change and be paged for this system next: what happened, why, what was done, and what would stop it happening again. Blame makes the next incident's facts harder to get, because people stop volunteering them, so describe systems, conditions and decisions, never a person's fault.

## Where things go

Find the incident's ROOT-CAUSE.md the way debug-incident does: with `KNACKPACK_DOCS=repo` set, in the folder `.knackpack/feature.json` names; otherwise on the intent record's Files line, or at the path the user gives. With none, or more than one that could be meant, ask which. Work in the checkout that holds the fix, the incident's `incident-<task>` branch when there is one (`git worktree list`).

Save the review as `INCIDENT.md` in the session scratchpad named in your system prompt, if there is one. Otherwise run `printenv TMPDIR` once (use `/tmp` if it prints nothing) and use the folder `claude-${CLAUDE_SESSION_ID}` inside it, writing the folder's full path literally in every later command. Create it with `mkdir -p -m 700 <folder>`, then check it with `[ -d <folder> ] && [ ! -L <folder> ] && [ -O <folder> ] && chmod 700 <folder>`; if the check fails, stop and tell the user. Add its path to the intent record's Files line. With `KNACKPACK_DOCS=repo` set, also write it to `.knackpack/<task>/INCIDENT.md`, beside ROOT-CAUSE.md, and commit that copy by running `sh "${CLAUDE_PLUGIN_ROOT}/scripts/commit-docs.sh" <the copy's absolute path>` from inside that checkout, since it commits in the repository of the folder it runs in; it commits the copy and `.knackpack/feature.json` alone and prints one line. Tell the user that line; when it starts with `not committed`, say why and give the scratch copy's path. The committed copy names nothing outside the repository, since it may be pushed. Never edit ROOT-CAUSE.md: its text is what was approved.

## Gather what happened

- **The diagnosis:** ROOT-CAUSE.md's incident, evidence, reproduction, hypotheses and cause. When its Status isn't `CONFIRMED`, there's no confirmed cause to review: say so, and write the review only if the user asks, as a draft that says the cause is unknown.
- **The fix:** `git diff <deployed SHA>` in the incident's checkout, which shows committed and uncommitted changes to tracked files, `git status --porcelain` for untracked ones, such as a regression test not yet added, and the commits on the branch since the deployed revision. Read what it changes; don't take a commit message's word for it.
- **The verification:** run the reproduction again as the diagnosis gives it, and record the result as `PASS`, `FAIL`, `NOT RUN`, `BLOCKED` or `SKIPPED`, with why for the last three. Add any other results the user or the fix's session reported, labeled with where they came from and not rerun.
- **What the user adds:** detection, response, communication, follow-up owners. Ask for what the review needs and the evidence doesn't hold, such as when the fix shipped, rather than guessing.

## Write it

Keep these headings, in this order, since tools read them:

```markdown
# Incident review: <the symptom in a few words>

Status: draft | final

## Summary

## Impact

## Timeline

## Cause

## Fix

## Verification

## Rollback

## Follow-ups

## Open questions
```

- **Status** is `draft` unless the user says the fix is deployed and the failure has stopped in production, the reproduction passes on the fix, and nothing under Open questions changes the cause; then it's `final`. A review that says an incident is resolved when it isn't sends everyone away too early, and a fix on a branch isn't in production.
- **Summary:** three or four sentences a reader who reads nothing else can act on.
- **Impact and Timeline:** from the diagnosis and the user, with times and their time zone, and estimates labeled as estimates.
- **Cause:** the mechanism from trigger to symptom, then the contributing factors, such as a missing test, an alert that didn't fire or a default that changed, kept apart from what's still speculation. Cite code by repository path and function, not by line alone.
- **Fix:** what changed and why that removes the cause, with the commit or branch, and what was deliberately left out of the fix.
- **Verification:** the results table, with only what actually ran called PASS.
- **Rollback:** from the fix's assessment, or your own reading of the diff: whether a revert is clean, and what instead when it isn't.
- **Follow-ups:** actions that would reduce recurrence or detect it sooner, each concrete enough to file, with an owning team or role only where the user named one.
- **Open questions:** what nobody knows yet.

No names of people as causes, and no "human error": write what the system allowed, such as "the deploy script accepted an empty region". Quote only redacted evidence: no tokens, passwords, keys, personal or customer data, and no raw logs or screenshots. Put what the reader must do or decide first, leave out filler, and write nothing the evidence doesn't support.

Reply with where the review is saved, or what commit-docs.sh printed, its Status, and the follow-ups. Offer `/knackpack:create-issues` to file the follow-ups; filing them publishes, so only on request.
