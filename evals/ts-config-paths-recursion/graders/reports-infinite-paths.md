---
type: llm
---

The uncommitted `src/config/get.ts` defines a recursive `Paths<T>` that builds every dotted path with template literal types, recursing into array items with `${number}`, and `getConfigValue<P extends Paths<AppConfig>>`. `AppConfig.navigation` (in `src/config/schema.ts`) holds `MenuItem`, whose `children` is `MenuItem[]`, so the paths are infinite: `navigation.header.0.children.0.children...`. Under TypeScript 5.9.3, `tsc -p .` fails with `src/config/get.ts(27,42): error TS2589: Type instantiation is excessively deep and possibly infinite.` and exits 2, so the build script fails. Without the change, or with `children` not self-referencing, or with a depth-limited `Paths`, the project type-checks cleanly.
PASS if the review reports that `Paths<AppConfig>` recurses without bound because `MenuItem` refers to itself, states that tsc fails on it (TS2589, "excessively deep", or the build breaking), and grades it Medium or higher. A proposed fix such as a depth limit, skipping the recursive subtree, or a simpler signature strengthens the answer but isn't required.
FAIL if it doesn't identify the self-referencing `MenuItem` as what the type can't handle, says the type works or only "might be slow" without establishing a failure or measured cost, calls it only a readability concern, or grades the finding Low.
