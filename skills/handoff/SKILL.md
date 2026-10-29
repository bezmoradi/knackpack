---
name: handoff
description: "Generate a high-level, self-contained code-review handoff and save it as HANDOFF.md in a private temporary folder outside the repository, so the user can pass a single file path to another coding agent acting as principal code reviewer, which writes its review to a file. Summarizes recent changes, the motivation, approach, alternatives, verification, risk, and what the reviewer should scrutinize. Use when the user wants a handoff or writeup to give another agent or person, not when they ask for a review here, which knackpack's reviewer agents do."
argument-hint: "[focus]"
---

# Handoff Writeup

Produce a focused, high-level writeup of the work most recently done so it can be handed off to another developer or coding agent for review. The full writeup goes to a file (see "Output & delivery" below) so the user can hand the receiving agent a single file path instead of copy-pasting; chat gets the path, a paste-ready instruction, and a brief summary — the full text goes to chat only if the user explicitly asks for it there. The reviewer works the same way: it writes its whole review to a file, beside the handoff unless its own instructions forbid that, and replies with only that file's path.

The structure follows widely used conventions for change descriptions: a commit-style lede, what and why, rejected alternatives, a reproducible test plan, and invariants phrased in RFC 2119 terms. Don't invent variants.

## Arguments

Optional free-text argument describing the scope to cover (e.g. `rate-limit fix`). If omitted, infer the scope from the recent conversation and the current uncommitted / recently committed changes — whichever most clearly represents "the work I want to hand off."

## Output & delivery

1. **Write the full writeup to a private folder outside the repository.** Use the session scratchpad named in your system prompt, if there is one. Otherwise run `printenv TMPDIR` once (use `/tmp` if it prints nothing) and use the folder `claude-${CLAUDE_SESSION_ID}` inside it, writing the folder's full path literally in every later command. Create it with `mkdir -p -m 700 <folder>`, then check it with `[ -d <folder> ] && [ ! -L <folder> ] && [ -O <folder> ] && chmod 700 <folder>`; if the check fails, stop and tell the user. Never write into the repository unless the user asks. Name the file `HANDOFF.md`, or `HANDOFF-<focus-slug>.md` when a focus was given (for example `HANDOFF-rate-limit-fix.md`), so a second handoff doesn't overwrite the first. The reviewer's review goes beside it as `REVIEW.md`, or `REVIEW-<focus-slug>.md` to match. Do not commit or push either file.

2. **Open the file with a role-setting preamble addressed to the receiving agent**, placed before all writeup sections:

   > You are a principal code reviewer, and ONLY a code reviewer — reviewing this handoff is your sole task; do not continue, extend, or fix the work described, and do not take on any other task. The writeup below hands off recently completed work for your review. Scrutinize it with the rigor of a principal engineer. Treat its Verification and Invariants sections as the author's claims, and verify them against the actual code. Build your own view of the risks from the code first, then work through the author's "What to scrutinize" list. You are report-only: you are NOT allowed to change any file in the repository; scratch files for your own checks go in a temporary folder outside it, which you delete afterwards. Your responsibility is only and only to report back the issues or improvements you find; deciding on and applying them stays with the author/owner. Write your entire review to `<absolute-path-to-the-review-file>`, never into the repository and not into your scratch folder, so your cleanup doesn't delete it, and reply with only that path. If your own instructions don't allow you to write there, save it where they do and reply with that path. If you run on another machine, give the review in your reply instead.

   Replace `<absolute-path-to-the-review-file>` with the review file's real absolute path.

3. **The file must be fully self-contained.** The receiving agent has NONE of this session's context — it sees only this file plus the repo. Therefore:
   - State on the first line after the preamble which repo the work is in — the reviewer may be launched from the monorepo root or from inside the repo.
   - Every file reference is a full `path:line` from the repo root, never "the file we just edited".
   - Name every symbol, sentinel, table, event, and command explicitly; never "the helper from earlier" or "as discussed above".
   - Do not reference this conversation, the user's earlier messages, or other scratchpad files, except the requirements brief, the plan and the session's intent record (`REQUIREMENTS.md`, `PLAN.md`, and the record from knackpack's intent tracking), which you may cite by absolute path.
   - Before finishing, re-read the file as a stranger would: any sentence that needs conversation context to parse must be rewritten.

4. **In chat, report** (in this order):
   - The absolute path to the handoff file, and the absolute path the review will be written to.
   - The exact instruction the user should give the reviewing agent: **"Read `<absolute-path-to-the-file>` in full, then carry out the review it describes and write it to `<absolute-path-to-the-review-file>`."**
   - A 3–5 line summary (the lede plus the top "What to scrutinize" items) so the user can sanity-check the handoff without opening the file.

   Caveat: a remote/cloud agent cannot read or write local paths — if the user says the reviewer is remote, paste the full text in chat instead; the reviewer will then give its review in its reply.

## Section structure

Sections marked **required** must appear. Sections marked **conditional** appear only when relevant — skip them entirely rather than padding. Sections marked **optional** are cheap one-liners; include when they add signal.

In order:

1. **Lede** *(optional, one line)* — imperative-mood summary in the style of a good commit subject (Google CL + Chris Beams). Doubles as the PR title candidate. Example: *"Close the token-refresh replay hole."* Skip for trivial changes.

2. **What this changes** *(required)* — one short paragraph. Behavior delta from the reviewer's perspective, not a code description.

3. **Why** *(required)* — the motivating problem. Cover:
   - The prior hole / bug / invariant that triggered the change.
   - The specific failure mode a user or system could have hit.
   - Any second-order issues surfaced during the fix.

4. **Approach** *(required)* — one paragraph. Concrete `path:line` references for the central change. Name the reused sentinel / helper / port so the reviewer can trace it. No code dumps. This is *how*, not *what*.

5. **Alternatives considered** *(conditional)* — include only when a non-obvious design decision was made. For each rejected alternative, name it and say briefly why it lost. Distinct from "Out of scope": alternatives are *rejected at this moment*; out-of-scope items are *deferred for later*. Skip entirely for straightforward fixes where no real choice existed.

6. **Deliberately out of scope** *(required if non-empty)* — bullet list. Prevents the reviewer from treating an omission as an oversight. Each bullet must explain *why* it was deferred, not just *what*. If nothing's out of scope, omit the section.

7. **Verification** *(required)* — how you convinced yourself the change works. Modeled on Meta's Test Plan norm: reproducible, not "ran locally" or "#yolo". Cover three things where applicable:
   - **Happy path**: the primary success case.
   - **Edge / error cases**: what you exercised that *should* fail, and how.
   - **Regression check**: what existing behavior you confirmed is unbroken.
   Use concrete inputs (curl commands, database keys, UI steps, log snippets). "Compiled and linted" is necessary but NOT sufficient.

8. **Requirements covered** *(conditional)* — when the work implements requirements with IDs (REQ-01 and so on), list each ID with where it's implemented and how it was verified, and cite the requirements brief, the plan and the intent record by absolute path when they exist.

9. **Risk / rollback** *(conditional)* — include for anything beyond a trivial refactor. One line is often enough. Cover: blast radius (which services / data / users), rollback procedure, any migration or feature-flag state, cross-service contract changes. Tie explicitly to deployment reality when relevant (rolling updates, event consumers, token claim shape, URL path contracts). Skip for pure local refactors that revert cleanly.

10. **Files touched** *(required)* — bullet list, one line per file, stating the role each plays (source / docs / reviewer rules / config). Purpose: let the reviewer pick the order to read them.

11. **What to scrutinize** *(required)* — numbered list of 3–6 items. These are the questions the reviewer should actively ask, derived from the *actual* risk surface of this diff. Each item states the concern and what a bad answer would look like. Do NOT restate generic review items (style, naming, error handling) — the reviewer already has those. Name the *specific* things you are worried about. This section is what distinguishes a senior-to-senior handoff from a generic summary.

12. **Invariants it relies on** *(required if any)* — bullet list. Load-bearing assumptions elsewhere in the codebase that the change trusts. If any of them change, the fix breaks silently; the reviewer should know. Encouraged: RFC 2119 phrasing ("This change relies on `Order.status` never moving backwards: a `shipped` order MUST NOT return to `pending`") for precision. If the change touches cross-service contracts (event payload shape, token claim, URL path segment, DB field rename, shared regex), call that out explicitly and name the consumer services.

13. **Related / Feedback ask** *(optional, one line each)* —
    - *Related*: tickets, incidents, prior PRs. Skip if none.
    - *Feedback ask*: what kind of review you want (GitHub's advice). Example: *"Design review on the validation placement; line-by-line not needed."* Skip if standard line-by-line is fine.

## Rules

- **Tone**: factual, senior-to-senior. The reviewer is a peer or principal, not a junior; don't over-explain language features or basic patterns. Name trade-offs; don't hide them. Admit shortcomings up front (Google CL guidance).
- **Do NOT include**: line counts, diff stats, marketing language ("clean", "elegant", "robust"), claims about test coverage the repo doesn't have, anything the reviewer can get from `git show` in two seconds.
- **Do include**: every invariant the change newly relies on, even if it feels obvious — the whole point of handoff is to surface implicit assumptions.
- **File references**: prefer `path:line` over bare function names; the reviewer will paste them into their editor.
- **Cross-service contracts**: if the change touches an event payload, token claim, URL path shape, DB field, or regex shared across services, flag it in *Invariants* and name every consumer service.
- **Known rough edges**: drift windows, stale caches, non-atomic updates, deferred backfills — name them under *Out of scope* or *Risk* with the reason. Do not hide them.
- **Doc changes**: list updates to instruction files, agent or rule files and architecture docs under *Files touched*, and say briefly what rule or invariant was added.

## Process

1. If no argument was provided, state the scope being covered in one line so the user can correct course (e.g., *"Covering the `UpdateProfile` validation change and the two doc updates from this session — say if you meant something else"*). Proceed without blocking.
2. If any facts are unclear, use read-only tools (`git log`, `git diff`, file reads) to pin them down before writing. Do NOT fabricate file paths, line numbers, sentinel names, or invariants.
3. Write the writeup to the file named in "Output & delivery" above, using markdown headings (not bolded titles). Length should be proportional to change complexity — trivial refactors get a short writeup, architectural changes get more.
4. Do not commit or push anything, and do not write the file anywhere except the folder named above, unless the user asks.

## What NOT to do

- Do not produce a generic "what I did" summary. The *Why*, *Verification*, and *What to scrutinize* sections are the reason this skill exists; without them the output is a changelog, not a handoff.
- Do not invent "what to scrutinize" items that don't tie to real risk in the actual diff. If the change is low-risk, say so and keep that section short.
- Do not include forward-looking roadmap items unless they were explicitly part of the change (e.g., "ownership transfer deferred" belongs; "we should also add X someday" does not).
- Do not sign off, add emojis, or include a "Co-Authored-By" line — this output is a writeup, not a commit.
- Do not pad with sections that don't apply. Better to skip *Alternatives considered* than to fabricate a rejected option.
