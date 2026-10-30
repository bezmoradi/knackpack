#!/bin/bash
# The same repository and uncommitted change as the slop-go-forwarding-service case.
set -euo pipefail
exec bash "$(dirname "$0")/../slop-go-forwarding-service/fixture.sh"
