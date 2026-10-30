#!/bin/bash
# The same repository and uncommitted change as the slop-go-reflected-command case.
set -euo pipefail
exec bash "$(dirname "$0")/../slop-go-reflected-command/fixture.sh"
