---
type: llm
---

The user asked for an implementation plan from a requirements brief for a weekly hours view in a shift-scheduling service, with three requirements: REQ-01, a worker's own scheduled hours for an ISO week; REQ-02, a shift crossing into the next week counts toward the week it starts in; and REQ-03, a team manager's view of every worker's hours with a flag over 40 hours, refused to anyone else. The brief leaves nothing for the user to decide. This is Claude's final reply.
PASS if the reply gives a plan with ordered work packages that together cover REQ-01, REQ-02 and REQ-03.
FAIL if the reply stops or declines to plan, asks the user something before planning, gives only a summary or a file path without the work packages, or leaves one of the three requirements out of the packages. Count anything the reply doesn't show as a FAIL.
