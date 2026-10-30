#!/bin/bash
# The same repository and uncommitted change as the slop-go-kill-switch-kept case.
set -euo pipefail
exec bash "$(dirname "$0")/../slop-go-kill-switch-kept/fixture.sh"
