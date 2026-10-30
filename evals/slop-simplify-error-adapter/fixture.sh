#!/bin/bash
# The same repository and uncommitted change as the slop-go-error-adapter-kept case.
set -euo pipefail
exec bash "$(dirname "$0")/../slop-go-error-adapter-kept/fixture.sh"
