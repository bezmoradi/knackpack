#!/bin/sh
# Installs the linters scripts/check.sh runs, at the versions pinned here and
# in this folder, into <dir>, for CI on Linux x86-64. Every download is
# checked against a pinned hash before it's used: pip and npm check the ones
# in requirements.txt and package-lock.json, and this script checks the
# SHA-256 of the three release archives below. Dependabot updates the pip
# and npm pins but not these three; to update one, take the new archive's
# SHA-256 from its GitHub release page and check it against the project's own
# checksum file.
#
#   sh .github/linters/install.sh <dir>    then put <dir>/bin on PATH

set -eu
dest=${1:?usage: install.sh <dir>}
here=$(cd "$(dirname -- "$0")" && pwd)
mkdir -p "$dest/bin" "$dest/download"

# <url> <sha256> <path of the binary in the archive>. tar writes the binary
# to stdout, so it creates no folders from the archive.
fetch() {
	archive=$dest/download/${1##*/}
	curl -fsSL --retry 3 -o "$archive" "$1"
	printf '%s  %s\n' "$2" "$archive" | sha256sum -c - >/dev/null
	tar -xzOf "$archive" "$3" >"$dest/bin/${3##*/}"
	chmod 755 "$dest/bin/${3##*/}"
}
fetch https://github.com/rhysd/actionlint/releases/download/v1.7.12/actionlint_1.7.12_linux_amd64.tar.gz \
	8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8 actionlint
fetch https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_linux_x64.tar.gz \
	551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb gitleaks
fetch https://github.com/lycheeverse/lychee/releases/download/lychee-v0.24.2/lychee-x86_64-unknown-linux-musl.tar.gz \
	73657a111819a30c47c08352896796f23d64e4eb2b3ed39b6d32149241566fc5 lychee-x86_64-unknown-linux-musl/lychee

# Wheels only, so installing runs no package's build code.
python3 -m venv "$dest/python"
"$dest/python/bin/pip" install --quiet --disable-pip-version-check \
	--require-hashes --only-binary :all: --no-deps -r "$here/requirements.txt"
for tool in codespell shellcheck zizmor; do ln -s "$dest/python/bin/$tool" "$dest/bin/$tool"; done

# The exact tree in the lockfile, with no install scripts run.
mkdir -p "$dest/node"
cp "$here/package.json" "$here/package-lock.json" "$dest/node/"
npm ci --prefix "$dest/node" --ignore-scripts --no-audit --no-fund --silent
ln -s "$dest/node/node_modules/.bin/markdownlint-cli2" "$dest/bin/markdownlint-cli2"

rm -rf "$dest/download"
