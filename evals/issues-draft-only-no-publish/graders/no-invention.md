---
type: llm
---

The user said only this: when you open an account and go back to the list, the status filter is cleared and people have to set it again. They gave no browser, version, environment, frequency, number or share of affected users, deadline, estimate, priority or assignee. The repository's bug form adds the label bug.
PASS if the draft states none of those as fact: no reproduction details beyond the user's (set a status filter, open an account, go back to the list), no affected percentage or user counts, no deadline, sprint or estimate, no assignee, no priority, and no list of browsers. Restating the user's steps, writing "unknown", asking about any of these as an open question, and the bug form's bug label are all fine.
FAIL if it presents any such detail the user didn't give as fact (for example "happens in Chrome and Safari", "affects 30% of agents" or a specific way of going back stated as the confirmed reproduction), or sets a priority, assignee, deadline or estimate.
