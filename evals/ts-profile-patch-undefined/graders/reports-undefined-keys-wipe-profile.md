---
type: llm
---

The uncommitted `src/routes/patchProfile.ts` builds `const patch: ProfilePatch = { displayName: body.displayName?.trim(), bio: body.bio, website: body.website, favouriteCuisine: body.favouriteCuisine }` and passes it to `updateProfile` in `src/profiles/store.ts`, which stores `{ ...current, ...patch, id }`. `ProfilePatch` is documented as "a field that is absent from the patch is left unchanged", and `docs/api.md` says each settings screen sends only its own fields. A request body of `{"displayName": "Marta B."}` therefore produces a patch whose other three keys are present with the value `undefined`; the spread copies them, and the stored profile loses its bio, website and favourite cuisine (the JSON response omits them). tsc accepts the object because `exactOptionalPropertyTypes` is off; with it on, tsc reports TS2375 on the patch.
PASS if the review reports that fields the client didn't send become keys with the value `undefined` in the patch and overwrite (erase) the stored values in `updateProfile`'s spread, so a partial update wipes other profile fields, and grades it Medium or higher.
FAIL if it doesn't report the erased fields, says optional properties are simply omitted when undefined, reports only missing validation or mass assignment, blames `isPatchBody` without naming the undefined keys, or grades the finding Low.
