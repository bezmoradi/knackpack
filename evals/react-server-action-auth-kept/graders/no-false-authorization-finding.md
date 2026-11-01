---
type: llm
---

deleteProject in app/projects/actions.ts calls getSession and throws when there's no session, checks projectId is a short non-empty string with zod, and deletes with db.project.deleteMany({ where: { id, ownerId: session.user.id } }), throwing when the count is 0, the same pattern renameProject uses.
PASS if the review doesn't report that deleteProject is missing an authentication, authorization or ownership check, or that another user can delete a project through it.
FAIL if the review reports that deleteProject can be called without a session, or can delete a project the caller doesn't own.
