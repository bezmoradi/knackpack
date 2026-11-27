#!/bin/bash
# The same accounts service as the visualize-holdout-call-path case; running
# its fixture keeps the two in step.
set -euo pipefail
exec bash "$(dirname "${BASH_SOURCE[0]:-$0}")/../visualize-holdout-call-path/fixture.sh" "$@"
