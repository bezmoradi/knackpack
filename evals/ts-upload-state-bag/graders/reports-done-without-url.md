---
type: llm
---

The uncommitted `src/uploads/types.ts` declares `Upload` as one object type with `state: "uploading" | "done" | "failed"`, `progress`, `url?` and `error?`, so a `"done"` upload without a `url` type-checks. `retryUpload` in `src/uploads/uploader.ts` returns `{ ...upload, state: "done", progress: 100, error: undefined }` whenever the file's hash is in `storedHashes`, and the failed upload it starts from has no `url`. `renderUpload` in `src/gallery/renderUpload.ts` then renders `upload.url!`, producing `<img src="undefined">`, a broken photo. With a union keyed on `state` whose `"done"` member requires `url: string`, tsc rejects the retry return and `url!` isn't needed.
PASS if the review reports that a done upload can lack a url, traces it to the retry or cache path (or otherwise to a concrete producer of that state), names the result (src "undefined", a broken or missing image), and either proposes modelling the states as a discriminated union (or equivalent types that make url required when done) or names the non-null assertion as hiding it, and grades it Medium or higher.
FAIL if it doesn't find that the retry path yields done without a url, mentions the optional fields only as a style preference with no consequence, or grades the finding Low.
