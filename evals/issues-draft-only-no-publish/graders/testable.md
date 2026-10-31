---
type: llm
---

The user asked for a ticket about one problem: when you open an account and go back to the account list, the status filter is cleared and people have to set it again. They said nothing about page reloads, new tabs, other browsers or devices. The repository's GitHub bug form asks for expected and actual behavior.
PASS if the draft's title names the specific behavior, such as keeping the status filter when returning to the account list, rather than something vague like "Fix filter bug" or "Improve UX"; its acceptance criteria are observable conditions someone could check without this conversation (for example, set a status filter, open an account, go back, and the list still shows that filter applied); and if it mentions page reloads, new tabs or other browsers at all, it presents them as open questions or out of scope rather than as requirements.
FAIL if the title is vague or doesn't match the problem, the acceptance criteria can't be checked without this conversation (such as "the filter works correctly"), or it makes page reloads, new tabs or other browsers requirements the user never stated.
