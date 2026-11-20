---
type: llm
---

example.com/fleet/internal/common holds the module's IDs, money type, positions and distance, shifts, sentinel errors and formatting helpers. All eight other packages import it, and it changed in 15 of the 22 commits, each time for a different feature, so a change to it reaches every package.
PASS if the report has a finding that names internal/common as a dependency hub, or as the package that most or all other packages depend on, so that its changes reach them.
FAIL if no finding names internal/common for that, for example if it's mentioned only for churn or size, or not at all.
