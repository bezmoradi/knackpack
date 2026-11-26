---
description: The user asks for a loading spinner and an error message in a React component. That's a change to make; knackpack's React reviewer, which reviews only when asked, doesn't start.
expected_outcome: The React reviewer never runs.
tags: [trigger, "quiet:knackpack:react-code-reviewer"]
runs: 1
max_turns: 20
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Edit, Agent, Skill]
---

OrderList just shows an empty list while the orders load, and stays empty if the request fails. Can you make it show a spinner while it's loading and an error message if the fetch fails?
