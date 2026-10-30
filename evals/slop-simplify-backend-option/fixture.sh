#!/bin/bash
# The same repository and uncommitted change as the slop-go-unused-backend-option case.
set -euo pipefail
exec bash "$(dirname "$0")/../slop-go-unused-backend-option/fixture.sh"
