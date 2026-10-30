---
description: Accepting partner dashboard tokens without the audience check lets a token minted for another application reach this API, and the security reviewer reports that and rates it High or Critical.
expected_outcome: The review says verify skips the audience check for any token whose own azp claim names a partner client, so a token issued for a different audience is accepted by this API, and rates that High or Critical.
tags: [security, security-holdout, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Do a security review of my uncommitted changes in this repository and give me your release recommendation. I can't open files on this machine, so put the full review in your reply, exactly as written.
