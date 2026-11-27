#!/bin/bash
# The same orders app and event bus as the visualize-holdout-page case;
# running its fixture keeps the two in step.
set -euo pipefail
exec bash "$(dirname "${BASH_SOURCE[0]:-$0}")/../visualize-holdout-page/fixture.sh" "$@"
