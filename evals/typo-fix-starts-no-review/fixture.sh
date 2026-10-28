#!/bin/bash
# A tiny project whose README has one misspelled word.
set -euo pipefail
cat > README.md <<'MD'
# notify

A small tool that sends you a message when a long command finishes. You
recieve the message on the channel you set in `notify.toml`.
MD
