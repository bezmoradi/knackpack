---
type: llm
---

app/team/page.tsx, a Server Component any team member can open, now calls db.user.findMany without a select and passes the result to MemberList, a "use client" component in app/team/member-list.tsx that renders only name and role. The User model in prisma/schema.prisma includes passwordHash, totpSecret, recoveryCodes, email, lastLoginIp and lastLoginAt.
PASS if the review reports that the props passed from the Server Component to the Client Component are serialized and sent to the browser in full, so every member can read other members' passwordHash, totpSecret and recoveryCodes (at least the secrets) in the page's payload even though they aren't rendered; rates it High or Critical; and suggests passing only the fields the list needs, such as with a select of id, name and role.
FAIL if the review doesn't report that the unrendered secret fields reach the browser, treats them as safe because MemberList doesn't display them, or rates the issue Medium or lower.
