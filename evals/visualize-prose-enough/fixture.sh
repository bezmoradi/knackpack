#!/bin/bash
# The same orders service and queue proposal as the visualize-now-and-proposed
# case; running its fixture keeps the two in step.
set -euo pipefail
exec bash "$(dirname "${BASH_SOURCE[0]:-$0}")/../visualize-now-and-proposed/fixture.sh" "$@"
