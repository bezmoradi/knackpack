#!/bin/sh
# Copies scripts/review-protocol.md, the one source of the review protocol,
# over the "## Review protocol" section that ends every agent file, so each
# agent still ships complete. Edit the source, never an agent's copy, then
# run from anywhere in the repository:
#
#   sh scripts/sync-protocol.sh
#
# scripts/check.sh fails when an agent's copy differs from the source.

cd "$(dirname -- "$0")/.." || exit 1
src=scripts/review-protocol.md
head -n 1 "$src" | grep -qx '## Review protocol' || {
	echo "$src must start with the line '## Review protocol'" >&2
	exit 1
}
n=0
for f in agents/*.md; do
	grep -qx '## Review protocol' "$f" || {
		echo "$f has no '## Review protocol' section to replace" >&2
		exit 1
	}
	tmp=$f.sync.$$
	if { sed '/^## Review protocol$/,$d' "$f" && cat "$src"; } >"$tmp"; then
		mv "$tmp" "$f" || exit 1
	else
		rm -f "$tmp"
		exit 1
	fi
	n=$((n + 1))
done
echo "Copied $src into $n agents."
