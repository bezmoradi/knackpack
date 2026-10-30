#!/bin/bash
# The same repository and uncommitted change as the slop-go-boundary-validation-kept case.
set -euo pipefail
exec bash "$(dirname "$0")/../slop-go-boundary-validation-kept/fixture.sh"
