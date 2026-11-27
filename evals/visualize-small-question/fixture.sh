#!/bin/bash
# The same orders service as the visualize-call-path case; running its fixture
# keeps the two in step.
set -euo pipefail
exec bash "$(dirname "${BASH_SOURCE[0]:-$0}")/../visualize-call-path/fixture.sh" "$@"
