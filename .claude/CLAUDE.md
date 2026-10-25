# Working on knackpack

knackpack is a Claude Code plugin made only of Markdown: skills in `skills/<name>/SKILL.md` and agents in `agents/<name>.md`. The repository root is both the plugin and its marketplace, so every file at the root ships to every user. The README's Local Development section has the commands; this file holds the rules.

## Rules

- **Keep the review protocol identical.** All six agent files end with the same "Review protocol" section. Change it in one file, copy it to the other five, and check that this prints one checksum six times:
  `for f in agents/*.md; do sed -n '/^## Review protocol$/,$p' "$f" | shasum -a 256; done`
- **Keep the agents report-only.** Every agent lists its tools in `tools:` and never gets Edit, Write or NotebookEdit. Only the adversarial, ASVS and architecture reviewers get `Agent`, and they use it only to start `knackpack:adjudicator`. Keep `omitClaudeMd: true` on every agent.
- **Write everything yourself.** Don't copy text from other projects, even MIT-licensed ones, and don't include ASVS requirement text, which is licensed CC BY-SA; the ASVS reviewer downloads the release file and checks its checksum instead.
- **Keep it generic.** No company or product names from private projects, no email addresses, and no names of private repositories.
- **Check facts against primary sources:** the Claude Code docs, specs, RFCs and library source. Name the version when behavior changed in one.
- **Keep each `SKILL.md` under about 19,000 characters.** After compaction, Claude Code carries over only the first 5,000 tokens of each skill, and anything past that is lost.
- **Don't add `.mcp.json`, `hooks/`, `bin/` or `settings.json` at the root** unless every user should get them.

## Before you publish

1. Run `claude plugin validate .`. The only expected warning is the missing icon.
2. Check for misspelled frontmatter keys, which Claude Code ignores silently: start `claude --debug --plugin-dir .` and search the debug log in `~/.claude/debug/` for `does not recognize or apply`.
3. Bump `version` in `.claude-plugin/plugin.json`; installed copies update only when it changes.
4. Update the README when behavior changes, including the counts of skills and agents.
