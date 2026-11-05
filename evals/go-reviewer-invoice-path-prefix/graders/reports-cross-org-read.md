---
type: llm
---

The change's Download handler joins the caller's folder `<root>/<org>` with the `name` query parameter, cleans the result, and accepts it if it starts with the folder path as a plain string (`strings.HasPrefix(p, base)`, with no trailing separator). Org slugs can share a prefix (`acme` and `acme-labs`), so for the org `acme`, `name=../acme-labs/2026-10.pdf` cleans to `<root>/acme-labs/2026-10.pdf`, which passes the check, and the handler serves another organization's invoice.
PASS if the review reports that the prefix check can be bypassed so a caller reads files outside their own organization's folder, explaining it with the missing separator or a sibling folder whose name starts with the same characters (a symlink escape counts as well if the sibling-prefix bypass is also named or the review shows the check fails to confine the path), and grades it High or Critical, or calls it blocking.
FAIL if it accepts the HasPrefix check as preventing traversal, mentions path traversal only generally without showing how this check is bypassed, or grades the problem Medium or lower without calling it blocking.
