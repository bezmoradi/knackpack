# The requirements brief format, `knackpack-requirements/1`

Since 0.40.0, every requirements brief Challenge requirements writes is in this format, so a program can tell whether the brief is ready to plan from. Plan implementation and Execute plan check a brief with `scripts/requirements-check.sh` before planning from it, and Challenge requirements checks each brief after saving it. Its short form, which writes no brief, is unchanged.

The format checks exactly two rules, and stays that small: every requirement has an `Acceptance:` line, and every open question says `Blocking: yes` or `Blocking: no`. It has no dependencies between requirements, scenarios, links to tests or schema files.

## Example

````markdown
knackpack-requirements/1

### Readiness
- BLOCKED ON DECISIONS: Q-02 decides who may export.

### Requirements and acceptance criteria

#### REQ-01: Managers can export their own organization's orders
Acceptance: Given a manager of org A, when they export, the file holds only org A's orders; a manager of org B gets a 403.

#### REQ-02: An export over 10,000 rows is refused with a message
Acceptance: Exporting 10,001 rows answers "Too many rows; narrow the dates." and writes no file.

### Open questions and risks
- Q-01: Should exports include archived orders? Blocking: no
- Q-02: May support staff export across organizations? Blocking: yes
````

## What a brief holds

- **The marker line,** `knackpack-requirements/1`.
- **`### Readiness`,** for people. Nothing checks it. Challenge requirements writes `BLOCKED ON DECISIONS` there exactly when a question says `Blocking: yes`, but a program should read the questions, not this line.
- **`### Requirements and acceptance criteria`,** with one `#### <ID>: <text>` heading per requirement and a line starting `Acceptance:` in its body.
- **`### Open questions and risks`,** with one bullet per question, `- Q-<n>: <text> Blocking: yes` or `- Q-<n>: <text> Blocking: no`. Risks are other bullets in the same section. A brief with no open questions says `- None.` there.

## The check

`scripts/requirements-check.sh <file>` is the reference reader of the format: any other reader must give the same result for the same text. It's POSIX `sh`, reads only the file it's given, in one pass, writes nothing, and never fails or loops on any input. It prints exactly one line on standard output:

| Line | Exit | Meaning |
| --- | --- | --- |
| `ready` | 0 | The brief is valid and no question blocks. |
| `blocked Q-02 Q-05` | 1 | The IDs of every `Blocking: yes` question, in the brief's order, separated by one space. |
| `invalid: <reason>` | 2 | The brief breaks the format. The reason names the line number, and the ID where there is one, as in `invalid: line 12: REQ-03 has no Acceptance: line`. |
| `none` | 3 | The text has no marker line: a brief in the older format, or an empty file. |
| `error: <reason>` | 4 | Bad usage, meaning not exactly one argument, or a path that isn't a readable regular file. |

Act on the first word and the exit code; the reason's wording is for people.

## Reading rules

"Spaces" below means spaces and tabs.

1. **Lines.** Split the text on LF. Drop one CR at the end of a line, so CRLF reads as LF. A missing final newline is fine. Read bytes as bytes, without decoding UTF-8: a NUL byte, or any other byte these rules don't name, is just a byte and matches nothing. A UTF-8 byte-order mark (the bytes EF BB BF) at the very start of the text is removed before any rule reads the first line; anywhere else it's ordinary bytes.
2. **Marker.** The marker is a line that is exactly `knackpack-requirements/1` once spaces are trimmed from both ends, outside code fences. With no marker, the result is `none`, whatever else the text holds; an empty file is `none`. A second marker line is a problem (rule 6).
3. **Code fences.** A line that, after at most 3 leading spaces, starts with a run of 3 or more backticks or 3 or more tildes opens a fence. The fence closes at the next line that, after at most 3 leading spaces, holds a run of the same character at least as long as the opening run, with nothing after it but spaces. A fence that never closes runs to the end of the text. Every rule ignores fence lines and the lines inside a fence.
4. **Headings.** A heading is a line starting at column 0 with 1 to 6 `#` followed by a space, a tab or the end of the line. Its level is the number of `#`. The section headings match exactly, once trailing spaces are trimmed: `### Requirements and acceptance criteria` and `### Open questions and risks`. A section runs from its heading to the next heading of level 1, 2 or 3. A section heading that appears a second time is a problem.
5. **Requirements section.** Every level-4 heading in it must be `#### <ID>: <text>`: `#### `, then an ID matching `^[A-Z][A-Z0-9]*-[0-9]{1,4}$`, then `:`, then a space, then text that isn't blank. A level-4 heading of any other form is a problem. Text before the first level-4 heading is ignored. A requirement's body runs to the next heading of level 1 to 4, so level-5 and level-6 headings are part of the body. The body must hold a line that starts at column 0 with `Acceptance:` followed by at least one character that isn't a space.
6. **Questions section.** A top-level bullet is a line starting at column 0 with `- `. A top-level bullet that starts with `- Q-` followed by a digit must be a question, `- Q-<n>: <text>`, with `<n>` 1 to 4 digits, then `:`, a space and text that isn't blank; any other bullet starting `- Q-<digit>` is a problem. Other bullets and lines, such as risks or `- None.`, are ignored. A question's first line, the bullet line itself, must contain `Blocking:` exactly once and end, once trailing spaces are trimmed, with `Blocking: yes` or `Blocking: no`, exactly and in lowercase. Continuation lines aren't checked.

## Result

The reader goes through the text once, in document order.

1. With no marker line, the result is `none`.
2. Otherwise, the first problem tied to a line, in the order the lines are reached, makes the result `invalid`. The problems are:
   - a second marker line;
   - a second section heading;
   - a level-4 heading in the Requirements section that isn't a requirement heading;
   - a requirement ID used twice among the requirements, or a question ID used twice among the questions;
   - a requirement whose body ended without an `Acceptance:` line;
   - a `- Q-<digit>` bullet that isn't a question;
   - a question without exactly one valid `Blocking:` marker.

   A missing `Acceptance:` line is reported at the line that ends the requirement's body: the next heading, or the text's last line when the body runs to the end. When one heading both ends such a requirement and is a problem itself, as a malformed level-4 heading or a repeated section heading is, the heading's problem is reported.
3. With no problem tied to a line, the result is `invalid` for a missing Requirements section, then for a missing Questions section, then for a Requirements section with no requirement, the first that applies.
4. Otherwise, if any question says `Blocking: yes`, the result is `blocked`, with the IDs of every such question in document order.
5. Otherwise, the result is `ready`.

## Stability

These rules, the line forms and the script's output lines are knackpack's public interface. They change only with a new format version, `knackpack-requirements/2`; a brief in this format keeps meaning what it means here.

## Not a security boundary

Like `scripts/commit-docs.sh`, the check is for agents that follow knackpack's rules, not a security boundary: anything that can edit the brief can change what it says, and nothing stops an agent from planning without running the check. A tool that must hold planning back until the blocking questions are answered should read the brief itself, and with `KNACKPACK_DOCS=repo`, read the committed blob, `git cat-file blob <commit>:<path>`, rather than the working-tree file.
