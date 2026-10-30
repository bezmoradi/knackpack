#!/bin/bash
# The same repository and uncommitted change as the slop-go-auth-order-test-kept case.
set -euo pipefail
exec bash "$(dirname "$0")/../slop-go-auth-order-test-kept/fixture.sh"
