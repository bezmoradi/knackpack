---
description: A Vite and React support desk adds search-as-you-type whose effect debounces with a timer but never ignores or aborts a request already sent, while the API notes say short queries answer slower than long ones. The React reviewer reports that a slow response for an earlier query can arrive last and replace the results for what the user typed, so the list shows the wrong customers.
expected_outcome: The review reports that the effect in CustomerSearch clears only the timer, so once a request is in flight an older, slower response can land after a newer one and overwrite the results for the current query; it suggests ignoring stale responses or aborting with the signal searchCustomers accepts in the effect's cleanup, or a data library that handles it; with the plugin, the React reviewer ran.
tags: [react, react-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Do a code review of my uncommitted React changes in this repository. I can't open files on this machine, so put the full review in your reply, exactly as written.
